defmodule Estimation.Estimator do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @attitude_loop :attitude_loop
  @position_velocity_loop :position_velocity_loop
  @clear_is_value_current_callback :clear_is_value_current_callback
  @imu :imu
  @gps :gps
  @airspeed :airspeed
  @agl :agl
  @reset_estimation :reset_estimation
  def start_link(config) do
    Logger.debug("Start Estimation.Estimator GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ins_kf_module = Keyword.fetch!(config, :ins_kf_type)
    ins_kf_config = Keyword.fetch!(config, :ins_kf_config)
    ins_kf = apply(ins_kf_module, :new, [ins_kf_config])

    agl_kf_module = Keyword.fetch!(config, :agl_kf_type)
    agl_kf_config = Keyword.fetch!(config, :agl_kf_config)
    agl_kf = apply(agl_kf_module, :new, [agl_kf_config])

    state = %{
      ins_kf_config: ins_kf_config,
      agl_kf_config: agl_kf_config,
      min_speed_for_course: Keyword.fetch!(config, :min_speed_for_course),
      attitude_rad: %{},
      groundspeed_mps: 0,
      course_rad: 0,
      vertical_velocity_mps: 0.0,
      position_rrm: %{},
      agl_m: 0.0,
      ground_altitude_m: nil,
      airspeed_mps: 0.0,
      ins_kf: ins_kf,
      agl_kf: agl_kf,
      is_value_current: %{
        imu: false,
        gps: false,
        airspeed: false,
        agl: false
      },
      imu_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @imu},
          4 * LoopIntervals.imu_receive_max_ms()
        ),
      gps_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @gps},
          5 * LoopIntervals.gps_receive_max_ms()
        ),
      airspeed_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @airspeed},
          2 * LoopIntervals.airspeed_receive_max_ms()
        ),
      agl_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @agl},
          2 * LoopIntervals.rangefinder_receive_max_ms()
        )
    }

    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.dt_accel_gyro_val(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.gps_itow_position_velocity_val(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.gps_itow_relheading_val(), self())

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.attitude_publish_ms(),
      @attitude_loop
    )

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.position_velocity_publish_ms(),
      @position_velocity_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  def reset_estimation() do
    GenServer.cast(__MODULE__, @reset_estimation)
  end

  @impl GenServer
  def handle_cast(@reset_estimation, state) do
    Logger.warn("Reset estimation")
    ins_kf = apply(state.ins_kf.__struct__, :new, [state.ins_kf_config])
    agl_kf = apply(state.agl_kf.__struct__, :new, [state.agl_kf_config])

    is_value_current = %{
      imu: false,
      gps: false,
      airspeed: false,
      agl: false
    }

    {:noreply,
     %{
       state
       | ins_kf: ins_kf,
         agl_kf: agl_kf,
         is_value_current: is_value_current,
         ground_altitude_m: nil
     }}
  end

  @impl GenServer
  def handle_cast({Groups.dt_accel_gyro_val(), values}, state) do
    # Logger.error("est dtag: #{ViaUtils.Format.eftb_map(values, 4)}")
    # start_time = :erlang.monotonic_time(:nanosecond)
    ins_kf = apply(state.ins_kf.__struct__, :predict, [state.ins_kf, values])
    # end_time = :erlang.monotonic_time(:nanosecond)
    # Logger.debug("pdt: #{ViaUtils.Format.eftb((end_time - start_time) * 1.0e-6, 3)}ms")
    imu_watchdog = Watchdog.reset(state.imu_watchdog)
    is_value_current = Map.put(state.is_value_current, :imu, true)
    # elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{ViaUtils.imu_rpy_to_string(ins_kf.imu, 2)}")
    {:noreply,
     %{
       state
       | ins_kf: ins_kf,
         is_value_current: is_value_current,
         imu_watchdog: imu_watchdog
     }}
  end

  @impl GenServer
  def handle_cast(
        {Groups.gps_itow_position_velocity_val(), _itow_s, position_rrm, velocity_mps},
        state
      ) do
    # Logger.warn("rx gps")
    # start_time = :erlang.monotonic_time(:nanosecond)
    # Logger.error("EKF update with GPS: #{ViaUtils.Format.eftb_map(velocity_mps, 1)}")

    ins_kf =
      apply(state.ins_kf.__struct__, :update_from_gps, [state.ins_kf, position_rrm, velocity_mps])

    # end_time = :erlang.monotonic_time(:nanosecond)
    # Logger.debug("gpsdt: #{ViaUtils.Format.eftb((end_time - start_time) * 1.0e-6, 3)}ms")

    gps_watchdog = Watchdog.reset(state.gps_watchdog)
    is_value_current = Map.put(state.is_value_current, :gps, true)
    # {position, velocity} = apply(ins_kf.__struct__, :position_rrm_velocity_mps, [ins_kf])
    # Logger.error("new position: #{ViaUtils.Location.to_string(position)}")
    # Logger.debug("new velocity: #{ViaUtils.Format.eftb_map(velocity, 1)}")

    {:noreply,
     %{
       state
       | ins_kf: ins_kf,
         is_value_current: is_value_current,
         gps_watchdog: gps_watchdog
     }}
  end

  @impl GenServer
  def handle_cast(
        {Groups.gps_itow_relheading_val(), _itow_ms, rel_heading_rad},
        state
      ) do
    # Logger.error("EKF update with heading: #{ViaUtils.Format.eftb_deg(rel_heading_rad, 1)}")
    # start_time = :erlang.monotonic_time(:nanosecond)
    ins_kf = apply(state.ins_kf.__struct__, :update_from_heading, [state.ins_kf, rel_heading_rad])
    # end_time = :erlang.monotonic_time(:nanosecond)
    # Logger.debug("hdgdt: #{ViaUtils.Format.eftb((end_time - start_time) * 1.0e-6, 3)}ms")

    {:noreply, %{state | ins_kf: ins_kf}}
  end

  @impl GenServer
  def handle_info(@attitude_loop, state) do
    # Logger.debug("att loop: #{dt_s}")
    state =
      if state.is_value_current.imu do
        imu = state.ins_kf.imu
        attitude_rad = Map.take(imu, [SVN.roll_rad(), SVN.pitch_rad(), SVN.yaw_rad()])
        # Logger.warn("ES att: #{ViaUtils.Format.eftb_map_deg(attitude_rad, 1)}")

        ViaUtils.Comms.cast_local_msg_to_group(
          __MODULE__,
          {Groups.estimation_attitude(), attitude_rad},
          self()
        )

        %{state | attitude_rad: attitude_rad}
      else
        Logger.debug("IMU is not current.")
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@position_velocity_loop, state) do
    %{gps: gps_current, imu: imu_current, agl: agl_current, airspeed: airspeed_current} =
      state.is_value_current

    state =
      if gps_current and imu_current do
        {%{
           SVN.altitude_m() => altitude_m
         } = position_rrm,
         %{
           SVN.v_north_mps() => v_north_mps,
           SVN.v_east_mps() => v_east_mps,
           SVN.v_down_mps() => v_down_mps
         } = _velocity_mps} =
          apply(state.ins_kf.__struct__, :position_rrm_velocity_mps, [state.ins_kf])

        # Logger.debug("alt: #{ViaUtils.Format.eftb(position_rrm.altitude_m,2)}")
        # If the velocity is below a threshold, we use yaw instead

        %{SVN.roll_rad() => roll_rad, SVN.pitch_rad() => pitch_rad, SVN.yaw_rad() => yaw_rad} =
          state.attitude_rad

        {groundspeed_mps, course_rad} =
          ViaUtils.Motion.get_speed_course_for_velocity(
            v_north_mps,
            v_east_mps,
            state.min_speed_for_course,
            yaw_rad
          )

        # /#{Common.Utils.eftb_deg(Map.get(state.attitude, :yaw, 0),2)}")
        # Logger.debug("est course: #{ViaUtils.Format.eftb_deg(course_rad, 1)}")
        vertical_velocity_mps = -v_down_mps
        # Update AGL
        # Logger.debug("rpv: #{Common.Utils.eftb_deg(roll,1)}/#{Common.Utils.eftb_deg(pitch,1)}/#{zdot}")
        {agl_kf, agl_m, ground_altitude_m} =
          if agl_current do
            agl_kf =
              apply(state.agl_kf.__struct__, :predict, [
                state.agl_kf,
                roll_rad,
                pitch_rad,
                vertical_velocity_mps
              ])

            agl_m = apply(agl_kf.__struct__, :agl_m, [agl_kf])
            ground_altitude_m = altitude_m - agl_m
            {agl_kf, agl_m, ground_altitude_m}
          else
            ground_altitude_m =
              case state.ground_altitude_m do
                nil -> altitude_m
                ground_alt -> ground_alt
              end

            {state.agl_kf, altitude_m - ground_altitude_m, ground_altitude_m}
          end

        airspeed_mps = if airspeed_current, do: state.airspeed_mps, else: groundspeed_mps

        position =
          position_rrm
          |> Map.put(SVN.ground_altitude_m(), ground_altitude_m)
          |> Map.put(SVN.agl_m(), agl_m)

        velocity = %{
          groundspeed_mps: groundspeed_mps,
          vertical_velocity_mps: vertical_velocity_mps,
          course_rad: course_rad,
          airspeed_mps: airspeed_mps
        }

        ViaUtils.Comms.cast_local_msg_to_group(
          __MODULE__,
          {Groups.estimation_position_velocity(), position, velocity},
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
      else
        # Logger.debug("GPS is not current")
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_is_value_current_callback, key}, state) do
    Logger.warn(
      "#{inspect(__MODULE__)} clear #{inspect(key)}: #{inspect(get_in(state, [:is_value_current, key]))}"
    )

    state = put_in(state, [:is_value_current, key], false)
    {:noreply, state}
  end
end
