defmodule Estimation.Estimator do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @attitude_loop :attitude_loop
  @position_velocity_loop :position_velocity_loop
  @clear_is_value_current_callback :clear_is_value_current_callback
  @imu :imu
  @gps :gps
  @airspeed :airspeed
  @agl :agl
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
      ins_kf: ins_kf,
      agl_kf: agl_kf,
      start_time: :erlang.monotonic_time(:microsecond),
      is_value_current: %{
        imu: false,
        gps: false,
        airspeed: false,
        agl: false
      },
      imu_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @imu},
          2 * LoopIntervals.imu_receive_max_ms()
        ),
      gps_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @gps},
          5 * LoopIntervals.gps_receive_max_ms()
        ),
      airspeed_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @airspeed},
          2 *LoopIntervals.airspeed_receive_max_ms()
        ),
      agl_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @agl},
          2 * LoopIntervals.rangefinder_receive_max_ms()
        )
    }

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.dt_accel_gyro_val(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.gps_itow_position_velocity(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.gps_itow_relheading(), self())

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.attitude_publish_ms(),
      @attitude_loop
    )

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.position_velocity_publish_ms,
      @position_velocity_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.dt_accel_gyro_val(), values}, state) do
    ins_kf = apply(state.ins_kf.__struct__, :predict, [state.ins_kf, values])
    imu_watchdog = Watchdog.reset(state.imu_watchdog)
    is_value_current = Map.put(state.is_value_current, :imu, true)
    # elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{Estimation.Imu.Utils.rpy_to_string(ins_kf.imu, 2)}")
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
        {Groups.gps_itow_position_velocity(), _itow_s, position_rrm, velocity_mps},
        state
      ) do
    ins_kf =
      apply(state.ins_kf.__struct__, :update_from_gps, [state.ins_kf, position_rrm, velocity_mps])

    gps_watchdog = Watchdog.reset(state.gps_watchdog)
    is_value_current = Map.put(state.is_value_current, :gps, true)
    # {position, velocity} = Estimation.SevenStateEkf.position_rrm_velocity_mps(kf)
    # Logger.debug("new position: #{ViaUtils.Location.to_string(position)}")
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
        {Groups.gps_itow_relheading(), _itow_ms, rel_heading_rad},
        state
      ) do
    # Logger.debug("EKF update with heading: #{ViaUtils.Format.eftb_deg(rel_heading_rad, 1)}")
    ins_kf = apply(state.ins_kf.__struct__, :update_from_heading, [state.ins_kf, rel_heading_rad])

    {:noreply, %{state | ins_kf: ins_kf}}
  end

  @impl GenServer
  def handle_info(@attitude_loop, state) do
    # Logger.debug("att loop: #{dt_s}")
    state =
      if state.is_value_current.imu do
        imu = state.ins_kf.imu
        attitude_rad = %{roll_rad: imu.roll_rad, pitch_rad: imu.pitch_rad, yaw_rad: imu.yaw_rad}

        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          {Groups.estimation_attitude, attitude_rad},
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
    state =
      if state.is_value_current.gps do
        {position_rrm, velocity_mps} =
          apply(state.ins_kf.__struct__, :position_rrm_velocity_mps, [state.ins_kf])

        # Logger.debug("alt: #{ViaUtils.Format.eftb(position_rrm.altitude_m,2)}")
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
          if state.is_value_current.agl do
            agl_kf =
              apply(state.agl_kf.__struct__, :predict, [
                state.agl_kf,
                roll_rad,
                pitch_rad,
                vertical_velocity_mps
              ])

            agl_m = apply(agl_kf.__struct__, :agl_m, [agl_kf])
            ground_altitude_m = position_rrm.altitude_m - agl_m
            {agl_kf, agl_m, ground_altitude_m}
          else
            ground_altitude_m =
              if is_nil(state.ground_altitude_m),
                do: position_rrm.altitude_m,
                else: state.ground_altitude_m

            {state.agl_kf, position_rrm.altitude_m - ground_altitude_m, ground_altitude_m}
          end

        airspeed_mps =
          if state.is_value_current.airspeed, do: state.airspeed, else: groundspeed_mps

        position =
          Map.take(position_rrm, [:latitude_rad, :longitude_rad, :altitude_m])
          |> Map.put(:ground_altitude_m, ground_altitude_m)

        velocity = %{
          groundspeed_mps: groundspeed_mps,
          vertical_velocity_mps: vertical_velocity_mps,
          course_rad: course_rad,
          airspeed_mps: airspeed_mps
        }

        ViaUtils.Comms.send_local_msg_to_group(
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
        Logger.debug("GPS is not current")
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_is_value_current_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(get_in(state, [:is_value_current, key]))}")
    state = put_in(state, [:is_value_current, key], false)
    {:noreply, state}
  end
end
