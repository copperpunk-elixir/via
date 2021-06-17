defmodule Estimation.Estimator do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups

  def start_link(config) do
    Logger.debug("Start Estimation.Estimator GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ins_kf_module = Module.concat(Estimation, Keyword.fetch!(config, :ins_kf_type))
    ins_kf = apply(ins_kf_module, :new, [Keyword.fetch!(config, :ins_kf_config)])

    agl_kf_module = Module.concat(Estimation, Keyword.fetch!(config, :agl_kf_type))
    agl_kf = apply(agl_kf_module, :new, [Keyword.fetch!(config, :agl_kf_config)])

    state = %{
      min_speed_for_course: Keyword.fetch!(config, :min_speed_for_course),
      attitude_rad: %{},
      groundspeed_mps: 0,
      course_rad: 0,
      vertical_velocity_mps: 0.0,
      position_rrm: %{},
      agl_m: 0.0,
      ground_altitude_m: nil,
      airspeed_mps: 0.0,
      ins_kf_module: ins_kf_module,
      ins_kf: ins_kf,
      agl_kf_module: agl_kf_module,
      agl_kf: agl_kf,
      watchdog_fed: %{agl: false, airspeed: false},
      start_time: :erlang.monotonic_time(:microsecond)
      # ground_altitude: 0.0
    }

    Comms.Supervisor.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, Groups.dt_accel_gyro_val, self())
    Comms.Operator.join_group(__MODULE__, Groups.gps_itow_position_velocity, self())
    Comms.Operator.join_group(__MODULE__, Groups.gps_itow_relheading, self())

    ViaUtils.Process.start_loop(
      self(),
      config[:attitude_loop_interval_ms],
      {:attitude_loop, config[:attitude_loop_interval_ms] / 1000}
    )

    ViaUtils.Process.start_loop(
      self(),
      config[:position_speed_course_loop_interval_ms],
      {:position_speed_course_loop, config[:position_speed_course_loop_interval_ms] / 1000}
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.dt_accel_gyro_val, values}, state) do
    ins_kf = apply(state.ins_kf_module, :predict, [state.ins_kf, values])

    # elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{Imu.Utils.rpy_to_string(ins_kf.imu, 2)}")
    {:noreply, %{state | ins_kf: ins_kf}}
  end

  @impl GenServer
  def handle_cast({Groups.gps_itow_position_velocity, _itow_s, position_rrm, velocity_mps}, state) do
    # Logger.debug("EKF update with GPS: #{ViaUtils.Location.to_string(position_rrm)}")
    ins_kf = apply(state.ins_kf_module, :update_from_gps, [state.ins_kf, position_rrm, velocity_mps])
    # {position, velocity} = Estimation.SevenStateEkf.position_rrm_velocity_mps(kf)
    # Logger.debug("new position: #{ViaUtils.Location.to_string(position)}")
    # Logger.debug("new velocity: #{ViaUtils.Format.eftb_map(velocity, 1)}")

    {:noreply, %{state | ins_kf: ins_kf}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.gps_itow_relheading, _itow_ms, rel_heading_rad},
        state
      ) do
    # Logger.debug("EKF update with heading: #{ViaUtils.Format.eftb_deg(rel_heading_rad, 1)}")
    ins_kf = apply(state.ins_kf_module, :update_from_heading, [state.ins_kf, rel_heading_rad])

    {:noreply, %{state | ins_kf: ins_kf}}
  end

  @impl GenServer
  def handle_info({:attitude_loop, dt}, state) do
    # Logger.debug("att loop: #{dt}")
    imu = state.ins_kf.imu
    attitude_rad = %{roll_rad: imu.roll_rad, pitch_rad: imu.pitch_rad, yaw_rad: imu.yaw_rad}

    Comms.Operator.send_local_msg_to_group(
      __MODULE__,
      {Groups.estimation_attitude, attitude_rad, dt},
      self()
    )

    {:noreply, %{state | attitude_rad: attitude_rad}}
  end

  @impl GenServer
  def handle_info({:position_speed_course_loop, dt}, state) do
    {position_rrm, velocity_mps} = apply(state.ins_kf_module, :position_rrm_velocity_mps, [state.ins_kf])

    state =
      if is_nil(position_rrm) do
        state
      else
        # Watchdog.Active.feed(:pos_vel)
        # If the velocity is below a threshold, we use yaw instead
        {groundspeed_mps, course_rad} =
          ViaUtils.Motion.get_speed_course_for_velocity(
            velocity_mps.north,
            velocity_mps.east,
            state.min_speed_for_course,
            Map.get(state.attitude_rad, :yaw_rad, 0)
          )

        # Logger.debug("course/yaw: #{Common.Utils.eftb_deg(course,1)}/#{Common.Utils.eftb_deg(Map.get(state.attitude, :yaw, 0),2)}")
        vertical_velocity_mps = -velocity_mps.down
        attitude_rad = state.attitude_rad
        # Update AGL
        roll_rad = Map.get(attitude_rad, :roll_rad, 0)
        pitch_rad = Map.get(attitude_rad, :pitch_rad, 0)

        # Logger.debug("rpv: #{Common.Utils.eftb_deg(roll,1)}/#{Common.Utils.eftb_deg(pitch,1)}/#{zdot}")
        {agl_kf, agl_m, ground_altitude_m} =
          if state.watchdog_fed.agl do
            agl_kf =
              apply(state.agl_kf_module, :predict, [
                state.agl_kf,
                roll_rad,
                pitch_rad,
                vertical_velocity_mps
              ])

            agl_m = apply(state.agl_kf_module, :agl_m, [agl_kf])
            ground_altitude_m = position_rrm.altitude_m - agl_m
            {agl_kf, agl_m, ground_altitude_m}
          else
            ground_altitude_m =
              if is_nil(state.ground_altitude_m),
                do: position_rrm.altitude_m,
                else: state.ground_altitude_m

            {state.agl_kf, position_rrm.altitude_m - ground_altitude_m, ground_altitude_m}
          end

        airspeed_mps = if state.watchdog_fed.airspeed, do: state.airspeed, else: groundspeed_mps

        Comms.Operator.send_local_msg_to_group(
          __MODULE__,
          {Groups.estimation_position_speed_course_airspeed, position_rrm, groundspeed_mps, course_rad,
           airspeed_mps, dt},
          self()
        )

        %{
          state
          | position_rrm: position_rrm,
            groundspeed_mps: groundspeed_mps,
            course_rad: course_rad,
            vertical_velocity_mps: vertical_velocity_mps,
            agl_kf: agl_kf,
            agl_m: agl_m,
            ground_altitude_m: ground_altitude_m
        }
      end

    {:noreply, state}
  end
end
