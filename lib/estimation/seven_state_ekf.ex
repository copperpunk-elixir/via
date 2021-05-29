defmodule Estimation.SevenStateEkf do
  require Logger
  require Common.Constants, as: CC

  @expected_imu_dt 0.005

  defstruct ekf_state: nil,
            ekf_cov: nil,
            r_gps: nil,
            r_heading: nil,
            q_ekf: nil,
            imu: nil,
            origin: nil,
            heading_established: false

  def new() do
    config = Configuration.Module.Estimation.get_config("", "")[:estimator][:ekf_config]
    new(config)
  end

  def new(config) do
    %Estimation.SevenStateEkf{
      ekf_state: Keyword.fetch!(config, :init_state),
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

  @spec predict(struct(), list()) :: struct
  def predict(state, dt_accel_gyro) do
    imu = Estimation.Imu.Mahony.update(state.imu, dt_accel_gyro)
    [dt, ax, ay, az, _gx, _gy, _gz] = dt_accel_gyro
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
        [ekf_state_prev[6] + (az_inertial + CC.gravity()) * dt],
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

    {dx, dy} = Common.Utils.Location.dx_dy_between_points(origin, position_rrm)

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

    inv_mat = Estimation.Imu.Utils.Matrix.inv_66(mat_to_invert)

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
      delta_z = Common.Utils.Motion.constrain_angle_to_compass(heading_rad - state.ekf_state[7])

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
      Logger.debug("Established heading at #{Common.Utils.eftb_deg(heading_rad, 2)}")
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
      Matrex.set(acc, index, index, init_std_devs[index] * init_std_devs[index])
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
    ekf_state = state.ekf_state

    Common.Utils.Location.lla_from_point(state.origin, ekf_state[1], ekf_state[2])
    |> Map.put(:altitude_m, ekf_state[3])
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
      Common.Utils.Location.lla_from_point(state.origin, ekf_state[1], ekf_state[2])
      |> Map.put(:altitude_m, -ekf_state[3])

    velocity_mps = %{north: ekf_state[4], east: ekf_state[5], down: ekf_state[6]}
    {position_rrm, velocity_mps}
  end
end
