defmodule Estimation.Estimator do
  use GenServer
  require Logger
  @min_speed_for_course 0.1

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator GenServer")
    {:ok, process_id} = UtilsProcess.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    kf_module = Module.concat(Estimation, Keyword.fetch!(config, :kf_type))
    kf = apply(kf_module, :new, [Keyword.fetch!(config, :kf_config)])

    state = %{
      min_speed_for_course: @min_speed_for_course,
      bodyrate: %{},
      attitude: %{},
      velocity: %{},
      position: %{},
      vertical_velocity: 0.0,
      agl: 0.0,
      airspeed: 0.0,
      # laser_alt_ekf: Estimation.LaserAltimeterEkf.new([]),
      kf_module: kf_module,
      kf: kf,
      start_time: :erlang.monotonic_time(:microsecond)
      # ground_altitude: 0.0
    }

    Comms.Supervisor.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :dt_accel_gyro_val, self())
    Comms.Operator.join_group(__MODULE__, :gps_itow_position_velocity, self())
    Comms.Operator.join_group(__MODULE__, :gps_itow_relheading_reldistance, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:dt_accel_gyro_val, values}, state) do
    #  Logger.debug("vals: #{inspect(UtilsFormat.eftb_list(values,2))}")
    kf = apply(state.kf_module, :predict, [state.kf, values])

    imu = kf.imu
    rpy =
      Enum.map([imu.roll_rad, imu.pitch_rad, imu.yaw_rad], fn x ->
        UtilsMath.rad2deg(x)
      end)
    elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    Logger.debug("rpy: #{elapsed_time}: #{UtilsFormat.eftb_list(rpy, 2)}")
    {:noreply, %{state | kf: kf}}
  end

  @impl GenServer
  def handle_cast({:gps_itow_position_velocity, _itow_ms, position_rrm, velocity_mps}, state) do
    # Logger.debug("EKF update with GPS: #{Common.Utils.LatLonAlt.to_string(position_rrm)}")
    kf = apply(state.kf_module, :update_from_gps, [state.kf, position_rrm, velocity_mps])
    # {position, velocity} = Estimation.SevenStateEkf.position_rrm_velocity_mps(kf)
    # Logger.debug("new position: #{Common.Utils.LatLonAlt.to_string(position)}")
    # Logger.debug("new velocity: #{UtilsFormat.eftb_map(velocity, 1)}")

    {:noreply, %{state | kf: kf}}
  end

  @impl GenServer
  def handle_cast(
        {:gps_itow_relheading, _itow_ms, rel_heading_rad},
        state
      ) do
    # Logger.debug("EKF update with heading: #{UtilsFormat.eftb_deg(rel_heading_rad, 1)}")
    kf = apply(state.kf_module, :update_from_heading, [state.kf, rel_heading_rad])

    {:noreply, %{state | kf: kf}}
  end
end
