defmodule SevenStateEkf do
  use GenServer
  require Logger
  require Common.Constants, as: CC

  @num_states 7
  @expected_imu_dt 0.005
  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Logger.debug("Begin #{__MODULE__}: #{inspect(config)}")

    state = %{
      ekf_state: Keyword.fetch!(config, :init_state),
      ekf_cov: generate_ekf_cov(config),
      r_gps: generate_r_gps(config),
      r_heading: generate_r_heading(config),
      q_ekf: generate_q(config),
      imu:
        Estimation.Imu.Mahony.new(
          Keyword.fetch!(config, :two_kp),
          Keyword.fetch!(config, :two_ki)
        )
    }

    {:noreply, state}
  end

  @spec update_imu(struct(), list()) :: struct()
  def update_imu(imu, dt_accel_gyro) do
    Estimation.Imu.Mahony.update(imu, dt_accel_gyro)
  end

  @spec predict_state(map(), list(), float()) :: map()
  def predict_state(state, [ax, ay, az], dt) do
    imu = state.imu

    {rbg_prime, ax_inertial, ay_inertial, az_inertial} =
      get_rbg_prime_accel_inertial(imu.roll, imu.pitch, imu.yaw, ax, ay, az)

    ekf_state_prev = state.ekf_state
    ekf_state =
      Matrex.new([
        [ekf_state_prev[1] + ekf_state_prev[4] * dt],
        [ekf_state_prev[2] + ekf_state_prev[5] * dt],
        [ekf_state_prev[3] + ekf_state_prev[6] * dt],
        [ekf_state_prev[4] + ax_inertial * dt],
        [ekf_state_prev[5] + ay_inertial * dt],
        [ekf_state_prev[6] + (az_inertial - CC.gravity()) * dt],
        imu.yaw
      ])
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
    init_std_devs_t = Matrex.transpose(init_std_devs)
    Matrex.dot(init_std_devs_t, init_std_devs)
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
    Matrex.new(config[:gpsyaw_std])
    |> Matrex.square()
  end

  @spec generate_q(list()) :: struct()
  def generate_q(config) do
    Matrex.zeros(@num_states)
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
end
