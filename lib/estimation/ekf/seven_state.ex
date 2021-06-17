defmodule Estimation.Ekf.SevenState do
  require Logger
  require ViaUtils.Constants, as: VC

  @expected_imu_dt 0.005

  defstruct ekf_state: nil,
            ekf_cov: nil,
            r_gps: nil,
            r_heading: nil,
            q_ekf: nil,
            imu: nil,
            origin: nil,
            heading_established: false

  def new(config) do
    %Estimation.Ekf.SevenState{
      ekf_state: Matrex.zeros(7, 1),
      ekf_cov: generate_ekf_cov(config),
      r_gps: generate_r_gps(config),
      r_heading: generate_r_heading(config),
      q_ekf: generate_q(config),
      imu:
        Estimation.Imu.Mahony.new(
          Keyword.fetch!(config, :imu_kp),
          Keyword.fetch!(config, :imu_ki)
        )
    }
  end

  @spec predict(struct(), map()) :: struct
  def predict(state, dt_accel_gyro) do
    imu = Estimation.Imu.Mahony.update(state.imu, dt_accel_gyro)
    dt = dt_accel_gyro.dt
    ax = dt_accel_gyro.ax
    ay = dt_accel_gyro.ay
    az = dt_accel_gyro.az

    # Acceleration due to gravity is measured in the negative-Z direction

    # Predict State
    {rbg_prime, ax_inertial, ay_inertial, az_inertial} =
      get_rbg_prime_accel_inertial(imu.roll_rad, imu.pitch_rad, imu.yaw_rad, ax, ay, az)

    ekf_state_prev = state.ekf_state

    ekf_state =
      Matrex.new([
        [ekf_state_prev[1] + ekf_state_prev[4] * dt],
        [ekf_state_prev[2] + ekf_state_prev[5] * dt],
        [ekf_state_prev[3] + ekf_state_prev[6] * dt],
        [ekf_state_prev[4] + ax_inertial * dt],
        [ekf_state_prev[5] + ay_inertial * dt],
        [ekf_state_prev[6] + (az_inertial + VC.gravity()) * dt],
        [imu.yaw_rad]
      ])

    # IO.puts("new state: #{inspect(ekf_state)}")

    accel = Matrex.new([[ax], [ay], [az]])
    g_prime_sub = Matrex.dot(rbg_prime, accel)
    # Update Covariance Matrix
    g_prime =
      Matrex.eye(7)
      |> Matrex.set(1, 4, dt)
      |> Matrex.set(2, 5, dt)
      |> Matrex.set(3, 6, dt)
      |> Matrex.set(4, 7, g_prime_sub[1])
      |> Matrex.set(5, 7, g_prime_sub[2])
      |> Matrex.set(6, 7, g_prime_sub[3])

    ekf_cov =
      Matrex.dot(g_prime, state.ekf_cov)
      |> Matrex.dot_and_add(Matrex.transpose(g_prime), state.q_ekf)

    # IO.puts("state: #{inspect(ekf_state)}")
    # IO.puts("new cov: #{inspect(ekf_cov)}")
    %{state | imu: imu, ekf_state: ekf_state, ekf_cov: ekf_cov}
  end

  # ----------------- PLEASE READ ---------------
  # GPS uses a geodetic coordinate system, with Latitude/Longitude/Altitude,
  # where Altitude is more positive as one moves away from the earth's surface.
  # Our EKF coordinate frame is NED, where the Z value is more negative as we move
  # away from the earth's surface.
  # Everything inside the EKF will be in NED coordinates
  # When we send a position to the outside, we convert to LLA
  @spec update_from_gps(struct(), map(), map()) :: struct()
  def update_from_gps(state, position_rrm, velocity_mps) do
    origin =
      if is_nil(state.origin) do
        position_rrm |> Map.put(:altitude_m, -position_rrm.altitude_m)
      else
        state.origin
      end

    {dx, dy} = ViaUtils.Location.dx_dy_between_points(origin, position_rrm)

    dz = -position_rrm.altitude_m - origin.altitude_m

    z =
      Matrex.new([
        [dx],
        [dy],
        [dz],
        [velocity_mps.north],
        [velocity_mps.east],
        [velocity_mps.down]
      ])

    # IO.puts("dz: #{inspect(dz)}")
    # IO.puts("z: #{inspect(z)}")

    h_prime =
      Matrex.zeros(6, 7)
      |> Matrex.set(1, 1, 1.0)
      |> Matrex.set(2, 2, 1.0)
      |> Matrex.set(3, 3, 1.0)
      |> Matrex.set(4, 4, 1.0)
      |> Matrex.set(5, 5, 1.0)
      |> Matrex.set(6, 6, 1.0)

    z_from_x = Matrex.submatrix(state.ekf_state, 1..6, 1..1)

    # Update
    ekf_cov = state.ekf_cov
    h_prime_transpose = Matrex.transpose(h_prime)

    mat_to_invert =
      Matrex.dot(h_prime, ekf_cov)
      |> Matrex.dot(h_prime_transpose)
      |> Matrex.add(state.r_gps)

    inv_mat = inv_66(mat_to_invert)

    k =
      Matrex.dot(ekf_cov, h_prime_transpose)
      |> Matrex.dot(inv_mat)

    delta_z = Matrex.subtract(z, z_from_x)
    k_add = Matrex.dot(k, delta_z)
    ekf_state = Matrex.add(state.ekf_state, k_add)

    eye_m_kh =
      Matrex.dot(k, h_prime)
      |> Matrex.subtract_inverse(Matrex.eye(7))

    ekf_cov = Matrex.dot(eye_m_kh, ekf_cov)
    %{state | ekf_state: ekf_state, ekf_cov: ekf_cov, origin: origin}
  end

  @spec update_from_heading(struct(), float()) :: struct()
  def update_from_heading(state, heading_rad) do
    if state.heading_established do
      delta_z = ViaUtils.Math.constrain_angle_to_compass(heading_rad - state.ekf_state[7])

      ekf_cov = state.ekf_cov
      r_heading = state.r_heading
      mat_div = ekf_cov[7][7] + r_heading[1]
      inv_mat = if mat_div != 0, do: 1 / mat_div, else: 0

      k =
        Matrex.submatrix(ekf_cov, 1..7, 7..7)
        |> Matrex.multiply(inv_mat)

      k_add = Matrex.multiply(k, delta_z)

      ekf_state = Matrex.add(state.ekf_state, k_add)

      eye_m_kh =
        Enum.reduce(1..7, Matrex.eye(7), fn index, acc ->
          if index < 7 do
            Matrex.set(acc, index, 7, k[index])
          else
            Matrex.set(acc, index, 7, 1 - k[index])
          end
        end)

      ekf_cov = Matrex.dot(eye_m_kh, ekf_cov)

      delta_yaw = k_add[7]
      imu = Imu.Utils.rotate_yaw_rad(state.imu, delta_yaw)
      %{state | imu: imu, ekf_state: ekf_state, ekf_cov: ekf_cov}
    else
      Logger.debug("Established heading at #{ViaUtils.Format.eftb_deg(heading_rad, 2)}")
      ekf_state = state.ekf_state |> Matrex.set(7, 1, heading_rad)
      %{state | ekf_state: ekf_state, heading_established: true}
    end
  end

  @spec get_rbg_prime_accel_inertial(float(), float(), float(), float(), float(), float()) ::
          tuple()
  def get_rbg_prime_accel_inertial(roll, pitch, yaw, ax, ay, az) do
    cosphi = :math.cos(roll)
    sinphi = :math.sin(roll)
    costheta = :math.cos(pitch)
    sintheta = :math.sin(pitch)
    cospsi = :math.cos(yaw)
    sinpsi = :math.sin(yaw)

    rbg_prime =
      Matrex.new([
        [
          -costheta * sinpsi,
          -sinphi * sintheta * sinpsi - cosphi * cospsi,
          -cosphi * sintheta * sinpsi + sinphi * cospsi
        ],
        [
          costheta * cospsi,
          sinphi * sintheta * cospsi - cosphi * sinpsi,
          cosphi * sintheta * cospsi + sinphi * sinpsi
        ],
        [0, 0, 0]
      ])

    accel_inertial_x =
      az * (sinphi * sinpsi + cosphi * cospsi * sintheta) -
        ay * (cosphi * sinpsi - cospsi * sinphi * sintheta) + ax * cospsi * costheta

    accel_inertial_y =
      ay * (cosphi * cospsi + sinphi * sinpsi * sintheta) -
        az * (cospsi * sinphi - cosphi * sinpsi * sintheta) + ax * costheta * sinpsi

    accel_inertial_z = az * cosphi * costheta - ax * sintheta + ay * costheta * sinphi

    {rbg_prime, accel_inertial_x, accel_inertial_y, accel_inertial_z}
  end

  @spec generate_ekf_cov(list()) :: struct()
  def generate_ekf_cov(config) do
    init_std_devs = Keyword.fetch!(config, :init_std_devs)

    Enum.reduce(1..7, Matrex.zeros(7), fn index, acc ->
      Matrex.set(
        acc,
        index,
        index,
        Enum.at(init_std_devs, index - 1) * Enum.at(init_std_devs, index - 1)
      )
    end)
  end

  @spec generate_r_gps(list()) :: struct()
  def generate_r_gps(config) do
    Matrex.zeros(6)
    |> Matrex.set(1, 1, config[:gpspos_xy_std])
    |> Matrex.set(2, 2, config[:gpspos_xy_std])
    |> Matrex.set(3, 3, config[:gpspos_z_std])
    |> Matrex.set(4, 4, config[:gpsvel_xy_std])
    |> Matrex.set(5, 5, config[:gpsvel_xy_std])
    |> Matrex.set(6, 6, config[:gpsvel_z_std])
    |> Matrex.square()
  end

  @spec generate_r_heading(list()) :: struct()
  def generate_r_heading(config) do
    Matrex.new([[config[:gpsyaw_std]]])
    |> Matrex.square()
  end

  @spec generate_q(list()) :: struct()
  def generate_q(config) do
    Matrex.zeros(7)
    |> Matrex.set(1, 1, config[:qpos_xy_std])
    |> Matrex.set(2, 2, config[:qpos_xy_std])
    |> Matrex.set(3, 3, config[:qpos_z_std])
    |> Matrex.set(4, 4, config[:qvel_xy_std])
    |> Matrex.set(5, 5, config[:qvel_xy_std])
    |> Matrex.set(6, 6, config[:qvel_z_std])
    |> Matrex.set(7, 7, config[:qyaw_std])
    |> Matrex.square()
    |> Matrex.multiply(@expected_imu_dt)
  end

  @spec position_rrm(struct()) :: struct()
  def position_rrm(state) do
    if is_nil(state.origin) do
      nil
    else
      ekf_state = state.ekf_state

      ViaUtils.Location.location_from_point_with_dx_dy(state.origin, ekf_state[1], ekf_state[2])
      |> Map.put(:altitude_m, ekf_state[3])
    end
  end

  @spec velocity_mps(struct()) :: map()
  def velocity_mps(state) do
    ekf_state = state.ekf_state
    %{north: ekf_state[4], east: ekf_state[5], down: ekf_state[6]}
  end

  @spec position_rrm_velocity_mps(struct()) :: tuple()
  def position_rrm_velocity_mps(state) do
    ekf_state = state.ekf_state

    position_rrm =
      if is_nil(state.origin) do
        nil
      else
        ViaUtils.Location.location_from_point_with_dx_dy(state.origin, ekf_state[1], ekf_state[2])
        |> Map.put(:altitude_m, -ekf_state[3])
      end

    velocity_mps = %{north: ekf_state[4], east: ekf_state[5], down: ekf_state[6]}
    {position_rrm, velocity_mps}
  end

  @spec inv_66(struct()) :: struct()
  def inv_66(m) do
    m11 = m[1][1]
    m12 = m[1][2]
    m13 = m[1][3]
    m14 = m[1][4]
    m15 = m[1][5]
    m16 = m[1][6]
    m21 = m[2][1]
    m22 = m[2][2]
    m23 = m[2][3]
    m24 = m[2][4]
    m25 = m[2][5]
    m26 = m[2][6]
    m31 = m[3][1]
    m32 = m[3][2]
    m33 = m[3][3]
    m34 = m[3][4]
    m35 = m[3][5]
    m36 = m[3][6]
    m41 = m[4][1]
    m42 = m[4][2]
    m43 = m[4][3]
    m44 = m[4][4]
    m45 = m[4][5]
    m46 = m[4][6]
    m51 = m[5][1]
    m52 = m[5][2]
    m53 = m[5][3]
    m54 = m[5][4]
    m55 = m[5][5]
    m56 = m[5][6]
    m61 = m[6][1]
    m62 = m[6][2]
    m63 = m[6][3]
    m64 = m[6][4]
    m65 = m[6][5]
    m66 = m[6][6]

    a4545 = m55 * m66 - m56 * m65
    a3545 = m54 * m66 - m56 * m64
    a3445 = m54 * m65 - m55 * m64
    a2545 = m53 * m66 - m56 * m63
    a2445 = m53 * m65 - m55 * m63
    a2345 = m53 * m64 - m54 * m63
    a1545 = m52 * m66 - m56 * m62
    a1445 = m52 * m65 - m55 * m62
    a1345 = m52 * m64 - m54 * m62
    a1245 = m52 * m63 - m53 * m62
    a0545 = m51 * m66 - m56 * m61
    a0445 = m51 * m65 - m55 * m61
    a0345 = m51 * m64 - m54 * m61
    a0245 = m51 * m63 - m53 * m61
    a0145 = m51 * m62 - m52 * m61
    a4535 = m45 * m66 - m46 * m65
    a3535 = m44 * m66 - m46 * m64
    a3435 = m44 * m65 - m45 * m64
    a2535 = m43 * m66 - m46 * m63
    a2435 = m43 * m65 - m45 * m63
    a2335 = m43 * m64 - m44 * m63
    a1535 = m42 * m66 - m46 * m62
    a1435 = m42 * m65 - m45 * m62
    a1335 = m42 * m64 - m44 * m62
    a1235 = m42 * m63 - m43 * m62
    a4534 = m45 * m56 - m46 * m55
    a3534 = m44 * m56 - m46 * m54
    a3434 = m44 * m55 - m45 * m54
    a2534 = m43 * m56 - m46 * m53
    a2434 = m43 * m55 - m45 * m53
    a2334 = m43 * m54 - m44 * m53
    a1534 = m42 * m56 - m46 * m52
    a1434 = m42 * m55 - m45 * m52
    a1334 = m42 * m54 - m44 * m52
    a1234 = m42 * m53 - m43 * m52
    a0535 = m41 * m66 - m46 * m61
    a0435 = m41 * m65 - m45 * m61
    a0335 = m41 * m64 - m44 * m61
    a0235 = m41 * m63 - m43 * m61
    a0534 = m41 * m56 - m46 * m51
    a0434 = m41 * m55 - m45 * m51
    a0334 = m41 * m54 - m44 * m51
    a0234 = m41 * m53 - m43 * m51
    a0135 = m41 * m62 - m42 * m61
    a0134 = m41 * m52 - m42 * m51

    b345345 = m44 * a4545 - m45 * a3545 + m46 * a3445
    b245345 = m43 * a4545 - m45 * a2545 + m46 * a2445
    b235345 = m43 * a3545 - m44 * a2545 + m46 * a2345
    b234345 = m43 * a3445 - m44 * a2445 + m45 * a2345
    b145345 = m42 * a4545 - m45 * a1545 + m46 * a1445
    b135345 = m42 * a3545 - m44 * a1545 + m46 * a1345
    b134345 = m42 * a3445 - m44 * a1445 + m45 * a1345
    b125345 = m42 * a2545 - m43 * a1545 + m46 * a1245
    b124345 = m42 * a2445 - m43 * a1445 + m45 * a1245
    b123345 = m42 * a2345 - m43 * a1345 + m44 * a1245
    b045345 = m41 * a4545 - m45 * a0545 + m46 * a0445
    b035345 = m41 * a3545 - m44 * a0545 + m46 * a0345
    b034345 = m41 * a3445 - m44 * a0445 + m45 * a0345
    b025345 = m41 * a2545 - m43 * a0545 + m46 * a0245
    b024345 = m41 * a2445 - m43 * a0445 + m45 * a0245
    b023345 = m41 * a2345 - m43 * a0345 + m44 * a0245
    b015345 = m41 * a1545 - m42 * a0545 + m46 * a0145
    b014345 = m41 * a1445 - m42 * a0445 + m45 * a0145
    b013345 = m41 * a1345 - m42 * a0345 + m44 * a0145
    b012345 = m41 * a1245 - m42 * a0245 + m43 * a0145
    b345245 = m34 * a4545 - m35 * a3545 + m36 * a3445
    b245245 = m33 * a4545 - m35 * a2545 + m36 * a2445
    b235245 = m33 * a3545 - m34 * a2545 + m36 * a2345
    b234245 = m33 * a3445 - m34 * a2445 + m35 * a2345
    b145245 = m32 * a4545 - m35 * a1545 + m36 * a1445
    b135245 = m32 * a3545 - m34 * a1545 + m36 * a1345
    b134245 = m32 * a3445 - m34 * a1445 + m35 * a1345
    b125245 = m32 * a2545 - m33 * a1545 + m36 * a1245
    b124245 = m32 * a2445 - m33 * a1445 + m35 * a1245
    b123245 = m32 * a2345 - m33 * a1345 + m34 * a1245
    b345235 = m34 * a4535 - m35 * a3535 + m36 * a3435
    b245235 = m33 * a4535 - m35 * a2535 + m36 * a2435
    b235235 = m33 * a3535 - m34 * a2535 + m36 * a2335
    b234235 = m33 * a3435 - m34 * a2435 + m35 * a2335
    b145235 = m32 * a4535 - m35 * a1535 + m36 * a1435
    b135235 = m32 * a3535 - m34 * a1535 + m36 * a1335
    b134235 = m32 * a3435 - m34 * a1435 + m35 * a1335
    b125235 = m32 * a2535 - m33 * a1535 + m36 * a1235
    b124235 = m32 * a2435 - m33 * a1435 + m35 * a1235
    b123235 = m32 * a2335 - m33 * a1335 + m34 * a1235
    b345234 = m34 * a4534 - m35 * a3534 + m36 * a3434
    b245234 = m33 * a4534 - m35 * a2534 + m36 * a2434
    b235234 = m33 * a3534 - m34 * a2534 + m36 * a2334
    b234234 = m33 * a3434 - m34 * a2434 + m35 * a2334
    b145234 = m32 * a4534 - m35 * a1534 + m36 * a1434
    b135234 = m32 * a3534 - m34 * a1534 + m36 * a1334
    b134234 = m32 * a3434 - m34 * a1434 + m35 * a1334
    b125234 = m32 * a2534 - m33 * a1534 + m36 * a1234
    b124234 = m32 * a2434 - m33 * a1434 + m35 * a1234
    b123234 = m32 * a2334 - m33 * a1334 + m34 * a1234
    b045245 = m31 * a4545 - m35 * a0545 + m36 * a0445
    b035245 = m31 * a3545 - m34 * a0545 + m36 * a0345
    b034245 = m31 * a3445 - m34 * a0445 + m35 * a0345
    b025245 = m31 * a2545 - m33 * a0545 + m36 * a0245
    b024245 = m31 * a2445 - m33 * a0445 + m35 * a0245
    b023245 = m31 * a2345 - m33 * a0345 + m34 * a0245
    b045235 = m31 * a4535 - m35 * a0535 + m36 * a0435
    b035235 = m31 * a3535 - m34 * a0535 + m36 * a0335
    b034235 = m31 * a3435 - m34 * a0435 + m35 * a0335
    b025235 = m31 * a2535 - m33 * a0535 + m36 * a0235
    b024235 = m31 * a2435 - m33 * a0435 + m35 * a0235
    b023235 = m31 * a2335 - m33 * a0335 + m34 * a0235
    b045234 = m31 * a4534 - m35 * a0534 + m36 * a0434
    b035234 = m31 * a3534 - m34 * a0534 + m36 * a0334
    b034234 = m31 * a3434 - m34 * a0434 + m35 * a0334
    b025234 = m31 * a2534 - m33 * a0534 + m36 * a0234
    b024234 = m31 * a2434 - m33 * a0434 + m35 * a0234
    b023234 = m31 * a2334 - m33 * a0334 + m34 * a0234
    b015245 = m31 * a1545 - m32 * a0545 + m36 * a0145
    b014245 = m31 * a1445 - m32 * a0445 + m35 * a0145
    b013245 = m31 * a1345 - m32 * a0345 + m34 * a0145
    b015235 = m31 * a1535 - m32 * a0535 + m36 * a0135
    b014235 = m31 * a1435 - m32 * a0435 + m35 * a0135
    b013235 = m31 * a1335 - m32 * a0335 + m34 * a0135
    b015234 = m31 * a1534 - m32 * a0534 + m36 * a0134
    b014234 = m31 * a1434 - m32 * a0434 + m35 * a0134
    b013234 = m31 * a1334 - m32 * a0334 + m34 * a0134
    b012245 = m31 * a1245 - m32 * a0245 + m33 * a0145
    b012235 = m31 * a1235 - m32 * a0235 + m33 * a0135
    b012234 = m31 * a1234 - m32 * a0234 + m33 * a0134

    c23452345 = m33 * b345345 - m34 * b245345 + m35 * b235345 - m36 * b234345
    c13452345 = m32 * b345345 - m34 * b145345 + m35 * b135345 - m36 * b134345
    c12452345 = m32 * b245345 - m33 * b145345 + m35 * b125345 - m36 * b124345
    c12352345 = m32 * b235345 - m33 * b135345 + m34 * b125345 - m36 * b123345
    c12342345 = m32 * b234345 - m33 * b134345 + m34 * b124345 - m35 * b123345
    c03452345 = m31 * b345345 - m34 * b045345 + m35 * b035345 - m36 * b034345
    c02452345 = m31 * b245345 - m33 * b045345 + m35 * b025345 - m36 * b024345
    c02352345 = m31 * b235345 - m33 * b035345 + m34 * b025345 - m36 * b023345
    c02342345 = m31 * b234345 - m33 * b034345 + m34 * b024345 - m35 * b023345
    c01452345 = m31 * b145345 - m32 * b045345 + m35 * b015345 - m36 * b014345
    c01352345 = m31 * b135345 - m32 * b035345 + m34 * b015345 - m36 * b013345
    c01342345 = m31 * b134345 - m32 * b034345 + m34 * b014345 - m35 * b013345
    c01252345 = m31 * b125345 - m32 * b025345 + m33 * b015345 - m36 * b012345
    c01242345 = m31 * b124345 - m32 * b024345 + m33 * b014345 - m35 * b012345
    c01232345 = m31 * b123345 - m32 * b023345 + m33 * b013345 - m34 * b012345
    c23451345 = m23 * b345345 - m24 * b245345 + m25 * b235345 - m26 * b234345
    c13451345 = m22 * b345345 - m24 * b145345 + m25 * b135345 - m26 * b134345
    c12451345 = m22 * b245345 - m23 * b145345 + m25 * b125345 - m26 * b124345
    c12351345 = m22 * b235345 - m23 * b135345 + m24 * b125345 - m26 * b123345
    c12341345 = m22 * b234345 - m23 * b134345 + m24 * b124345 - m25 * b123345
    c23451245 = m23 * b345245 - m24 * b245245 + m25 * b235245 - m26 * b234245
    c13451245 = m22 * b345245 - m24 * b145245 + m25 * b135245 - m26 * b134245
    c12451245 = m22 * b245245 - m23 * b145245 + m25 * b125245 - m26 * b124245
    c12351245 = m22 * b235245 - m23 * b135245 + m24 * b125245 - m26 * b123245
    c12341245 = m22 * b234245 - m23 * b134245 + m24 * b124245 - m25 * b123245
    c23451235 = m23 * b345235 - m24 * b245235 + m25 * b235235 - m26 * b234235
    c13451235 = m22 * b345235 - m24 * b145235 + m25 * b135235 - m26 * b134235
    c12451235 = m22 * b245235 - m23 * b145235 + m25 * b125235 - m26 * b124235
    c12351235 = m22 * b235235 - m23 * b135235 + m24 * b125235 - m26 * b123235
    c12341235 = m22 * b234235 - m23 * b134235 + m24 * b124235 - m25 * b123235
    c23451234 = m23 * b345234 - m24 * b245234 + m25 * b235234 - m26 * b234234
    c13451234 = m22 * b345234 - m24 * b145234 + m25 * b135234 - m26 * b134234
    c12451234 = m22 * b245234 - m23 * b145234 + m25 * b125234 - m26 * b124234
    c12351234 = m22 * b235234 - m23 * b135234 + m24 * b125234 - m26 * b123234
    c12341234 = m22 * b234234 - m23 * b134234 + m24 * b124234 - m25 * b123234
    c03451345 = m21 * b345345 - m24 * b045345 + m25 * b035345 - m26 * b034345
    c02451345 = m21 * b245345 - m23 * b045345 + m25 * b025345 - m26 * b024345
    c02351345 = m21 * b235345 - m23 * b035345 + m24 * b025345 - m26 * b023345
    c02341345 = m21 * b234345 - m23 * b034345 + m24 * b024345 - m25 * b023345
    c03451245 = m21 * b345245 - m24 * b045245 + m25 * b035245 - m26 * b034245
    c02451245 = m21 * b245245 - m23 * b045245 + m25 * b025245 - m26 * b024245
    c02351245 = m21 * b235245 - m23 * b035245 + m24 * b025245 - m26 * b023245
    c02341245 = m21 * b234245 - m23 * b034245 + m24 * b024245 - m25 * b023245
    c03451235 = m21 * b345235 - m24 * b045235 + m25 * b035235 - m26 * b034235
    c02451235 = m21 * b245235 - m23 * b045235 + m25 * b025235 - m26 * b024235
    c02351235 = m21 * b235235 - m23 * b035235 + m24 * b025235 - m26 * b023235
    c02341235 = m21 * b234235 - m23 * b034235 + m24 * b024235 - m25 * b023235
    c03451234 = m21 * b345234 - m24 * b045234 + m25 * b035234 - m26 * b034234
    c02451234 = m21 * b245234 - m23 * b045234 + m25 * b025234 - m26 * b024234
    c02351234 = m21 * b235234 - m23 * b035234 + m24 * b025234 - m26 * b023234
    c02341234 = m21 * b234234 - m23 * b034234 + m24 * b024234 - m25 * b023234
    c01451345 = m21 * b145345 - m22 * b045345 + m25 * b015345 - m26 * b014345
    c01351345 = m21 * b135345 - m22 * b035345 + m24 * b015345 - m26 * b013345
    c01341345 = m21 * b134345 - m22 * b034345 + m24 * b014345 - m25 * b013345
    c01451245 = m21 * b145245 - m22 * b045245 + m25 * b015245 - m26 * b014245
    c01351245 = m21 * b135245 - m22 * b035245 + m24 * b015245 - m26 * b013245
    c01341245 = m21 * b134245 - m22 * b034245 + m24 * b014245 - m25 * b013245
    c01451235 = m21 * b145235 - m22 * b045235 + m25 * b015235 - m26 * b014235
    c01351235 = m21 * b135235 - m22 * b035235 + m24 * b015235 - m26 * b013235
    c01341235 = m21 * b134235 - m22 * b034235 + m24 * b014235 - m25 * b013235
    c01451234 = m21 * b145234 - m22 * b045234 + m25 * b015234 - m26 * b014234
    c01351234 = m21 * b135234 - m22 * b035234 + m24 * b015234 - m26 * b013234
    c01341234 = m21 * b134234 - m22 * b034234 + m24 * b014234 - m25 * b013234
    c01251345 = m21 * b125345 - m22 * b025345 + m23 * b015345 - m26 * b012345
    c01241345 = m21 * b124345 - m22 * b024345 + m23 * b014345 - m25 * b012345
    c01251245 = m21 * b125245 - m22 * b025245 + m23 * b015245 - m26 * b012245
    c01241245 = m21 * b124245 - m22 * b024245 + m23 * b014245 - m25 * b012245
    c01251235 = m21 * b125235 - m22 * b025235 + m23 * b015235 - m26 * b012235
    c01241235 = m21 * b124235 - m22 * b024235 + m23 * b014235 - m25 * b012235
    c01251234 = m21 * b125234 - m22 * b025234 + m23 * b015234 - m26 * b012234
    c01241234 = m21 * b124234 - m22 * b024234 + m23 * b014234 - m25 * b012234
    c01231345 = m21 * b123345 - m22 * b023345 + m23 * b013345 - m24 * b012345
    c01231245 = m21 * b123245 - m22 * b023245 + m23 * b013245 - m24 * b012245
    c01231235 = m21 * b123235 - m22 * b023235 + m23 * b013235 - m24 * b012235
    c01231234 = m21 * b123234 - m22 * b023234 + m23 * b013234 - m24 * b012234

    det =
      (m11 *
         (m22 * c23452345 - m23 * c13452345 + m24 * c12452345 - m25 * c12352345 +
            m26 * c12342345))
      |> Kernel.+(
        -m12 *
          (m21 * c23452345 - m23 * c03452345 + m24 * c02452345 - m25 * c02352345 +
             m26 * c02342345)
      )
      |> Kernel.+(
        m13 *
          (m21 * c13452345 - m22 * c03452345 + m24 * c01452345 - m25 * c01352345 +
             m26 * c01342345)
      )
      |> Kernel.+(
        -m14 *
          (m21 * c12452345 - m22 * c02452345 + m23 * c01452345 - m25 * c01252345 +
             m26 * c01242345)
      )
      |> Kernel.+(
        m15 *
          (m21 * c12352345 - m22 * c02352345 + m23 * c01352345 - m24 * c01252345 +
             m26 * c01232345)
      )
      |> Kernel.+(
        -m16 *
          (m21 * c12342345 - m22 * c02342345 + m23 * c01342345 - m24 * c01242345 +
             m25 * c01232345)
      )

    det = if det != 0, do: 1 / det, else: 0

    Matrex.new([
      [
        det *
          (m22 * c23452345 - m23 * c13452345 + m24 * c12452345 - m25 * c12352345 +
             m26 * c12342345),
        det *
          -(m12 * c23452345 - m13 * c13452345 + m14 * c12452345 - m15 * c12352345 +
              m16 * c12342345),
        det *
          (m12 * c23451345 - m13 * c13451345 + m14 * c12451345 - m15 * c12351345 +
             m16 * c12341345),
        det *
          -(m12 * c23451245 - m13 * c13451245 + m14 * c12451245 - m15 * c12351245 +
              m16 * c12341245),
        det *
          (m12 * c23451235 - m13 * c13451235 + m14 * c12451235 - m15 * c12351235 +
             m16 * c12341235),
        det *
          -(m12 * c23451234 - m13 * c13451234 + m14 * c12451234 - m15 * c12351234 +
              m16 * c12341234)
      ],
      [
        det *
          -(m21 * c23452345 - m23 * c03452345 + m24 * c02452345 - m25 * c02352345 +
              m26 * c02342345),
        det *
          (m11 * c23452345 - m13 * c03452345 + m14 * c02452345 - m15 * c02352345 +
             m16 * c02342345),
        det *
          -(m11 * c23451345 - m13 * c03451345 + m14 * c02451345 - m15 * c02351345 +
              m16 * c02341345),
        det *
          (m11 * c23451245 - m13 * c03451245 + m14 * c02451245 - m15 * c02351245 +
             m16 * c02341245),
        det *
          -(m11 * c23451235 - m13 * c03451235 + m14 * c02451235 - m15 * c02351235 +
              m16 * c02341235),
        det *
          (m11 * c23451234 - m13 * c03451234 + m14 * c02451234 - m15 * c02351234 +
             m16 * c02341234)
      ],
      [
        det *
          (m21 * c13452345 - m22 * c03452345 + m24 * c01452345 - m25 * c01352345 +
             m26 * c01342345),
        det *
          -(m11 * c13452345 - m12 * c03452345 + m14 * c01452345 - m15 * c01352345 +
              m16 * c01342345),
        det *
          (m11 * c13451345 - m12 * c03451345 + m14 * c01451345 - m15 * c01351345 +
             m16 * c01341345),
        det *
          -(m11 * c13451245 - m12 * c03451245 + m14 * c01451245 - m15 * c01351245 +
              m16 * c01341245),
        det *
          (m11 * c13451235 - m12 * c03451235 + m14 * c01451235 - m15 * c01351235 +
             m16 * c01341235),
        det *
          -(m11 * c13451234 - m12 * c03451234 + m14 * c01451234 - m15 * c01351234 +
              m16 * c01341234)
      ],
      [
        det *
          -(m21 * c12452345 - m22 * c02452345 + m23 * c01452345 - m25 * c01252345 +
              m26 * c01242345),
        det *
          (m11 * c12452345 - m12 * c02452345 + m13 * c01452345 - m15 * c01252345 +
             m16 * c01242345),
        det *
          -(m11 * c12451345 - m12 * c02451345 + m13 * c01451345 - m15 * c01251345 +
              m16 * c01241345),
        det *
          (m11 * c12451245 - m12 * c02451245 + m13 * c01451245 - m15 * c01251245 +
             m16 * c01241245),
        det *
          -(m11 * c12451235 - m12 * c02451235 + m13 * c01451235 - m15 * c01251235 +
              m16 * c01241235),
        det *
          (m11 * c12451234 - m12 * c02451234 + m13 * c01451234 - m15 * c01251234 +
             m16 * c01241234)
      ],
      [
        det *
          (m21 * c12352345 - m22 * c02352345 + m23 * c01352345 - m24 * c01252345 +
             m26 * c01232345),
        det *
          -(m11 * c12352345 - m12 * c02352345 + m13 * c01352345 - m14 * c01252345 +
              m16 * c01232345),
        det *
          (m11 * c12351345 - m12 * c02351345 + m13 * c01351345 - m14 * c01251345 +
             m16 * c01231345),
        det *
          -(m11 * c12351245 - m12 * c02351245 + m13 * c01351245 - m14 * c01251245 +
              m16 * c01231245),
        det *
          (m11 * c12351235 - m12 * c02351235 + m13 * c01351235 - m14 * c01251235 +
             m16 * c01231235),
        det *
          -(m11 * c12351234 - m12 * c02351234 + m13 * c01351234 - m14 * c01251234 +
              m16 * c01231234)
      ],
      [
        det *
          -(m21 * c12342345 - m22 * c02342345 + m23 * c01342345 - m24 * c01242345 +
              m25 * c01232345),
        det *
          (m11 * c12342345 - m12 * c02342345 + m13 * c01342345 - m14 * c01242345 +
             m15 * c01232345),
        det *
          -(m11 * c12341345 - m12 * c02341345 + m13 * c01341345 - m14 * c01241345 +
              m15 * c01231345),
        det *
          (m11 * c12341245 - m12 * c02341245 + m13 * c01341245 - m14 * c01241245 +
             m15 * c01231245),
        det *
          -(m11 * c12341235 - m12 * c02341235 + m13 * c01341235 - m14 * c01241235 +
              m15 * c01231235),
        det *
          (m11 * c12341234 - m12 * c02341234 + m13 * c01341234 - m14 * c01241234 +
             m15 * c01231234)
      ]
    ])
  end
end
