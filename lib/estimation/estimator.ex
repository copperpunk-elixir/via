defmodule Estimation.Estimator do
  use GenServer
  require Logger
  @min_speed_for_course 0.1

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator GenServer")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
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
    ekf_module = Module.concat(Estimation, Keyword.fetch!(config, :ekf_type))
    ekf = apply(ekf_module, :new, [Keyword.fetch!(config, :ekf_config)])

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
      ekf_module: ekf_module,
      ekf: ekf,
      expected_antenna_distance_m: Keyword.get(config, :expected_antenna_distance_m, 0),
      antenna_distance_error_threshold_m:
        Keyword.get(config, :antenna_distance_error_threshold_m, -1),
      start_time: :erlang.monotonic_time(:microsecond)
      # ground_altitude: 0.0
    }

    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :dt_accel_gyro_val, self())
    Comms.Operator.join_group(__MODULE__, :gps_itow_position_velocity, self())
    Comms.Operator.join_group(__MODULE__, :gps_itow_relheading_reldistance, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:dt_accel_gyro_val, values}, state) do
    #  Logger.debug("vals: #{inspect(Common.Utils.eftb_list(values,2))}")
    ekf = apply(state.ekf_module, :predict, [state.ekf, values])
    imu = ekf.imu

    rpy =
      Enum.map([imu.roll_rad, imu.pitch_rad, imu.yaw_rad], fn x ->
        Common.Utils.Math.rad2deg(x)
      end)

    elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{Common.Utils.eftb_list(rpy, 2)}")
    {:noreply, %{state | ekf: ekf}}
  end

  @impl GenServer
  def handle_cast({:gps_itow_position_velocity, _itow_ms, position_rrm, velocity_mps}, state) do
    Logger.debug("EKF update with GPS: #{Common.Utils.LatLonAlt.to_string(position_rrm)}")
    ekf = apply(state.ekf_module, :update_from_gps, [state.ekf, position_rrm, velocity_mps])
    {position, velocity} = Estimation.SevenStateEkf.position_rrm_velocity_mps(ekf)
    Logger.debug("new position: #{Common.Utils.LatLonAlt.to_string(position)}")
    Logger.debug("new velocity: #{Common.Utils.eftb_map(velocity, 1)}")
    imu = ekf.imu

    rpy =
      Enum.map([imu.roll_rad, imu.pitch_rad, imu.yaw_rad], fn x ->
        Common.Utils.Math.rad2deg(x)
      end)

    Logger.debug("rpy: #{Common.Utils.eftb_list(rpy, 2)}")
    {:noreply, %{state | ekf: ekf}}
  end

  @impl GenServer
  def handle_cast(
        {:gps_itow_relheading_reldistance, _itow_ms, rel_heading_rad, rel_distance_m},
        state
      ) do
    ekf =
      if abs(rel_distance_m - state.expected_antenna_distance_m) <
           state.antenna_distance_error_threshold_m do
        Logger.debug("EKF update with heading: #{Common.Utils.eftb_deg(rel_heading_rad, 1)}")
        apply(state.ekf_module, :update_from_heading, [state.ekf, rel_heading_rad])
      else
        state.ekf
      end

    {:noreply, %{state | ekf: ekf}}
  end
end
