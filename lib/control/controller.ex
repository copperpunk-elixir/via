defmodule Control.Controller do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require MessageSorter.Sorter
  require Command.ControlTypes, as: CCT

  @controller_loop :controller_loop
  @clear_goals_callback :clear_goals_callback
  @clear_remote_pilot_override_callback :clear_remote_pilot_override_callback
  @agl_ceiling_m 150.0

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    {default_pilot_control_level, default_goals} =
      Keyword.fetch!(config, :default_goals) |> Map.to_list() |> Enum.at(0)

    controller_loop_interval_ms = Keyword.fetch!(config, :controller_loop_interval_ms)

    state = %{
      default_pilot_control_level: default_pilot_control_level,
      default_goals: default_goals,
      goals_store: %{},
      pilot_control_level: default_pilot_control_level,
      remote_pilot_goals_override: %{},
      remote_pilot_override: false,
      latch_course_rad: 0,
      latch_altitude_m: 0,
      latch_command_time_prev_ms: 0,
      ground_altitude_m: 0,
      course_rad: 0,
      groundspeed_mps: 0,
      altitude_m: 0,
      airspeed_mps: 0,
      attitude_rad: %{},
      controller_loop_interval_ms: controller_loop_interval_ms,
      clear_goals_timer: nil,
      clear_remote_pilot_override_timer: nil
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.commander_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.remote_pilot_goals_override(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude(), self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_groundalt_groundspeed_course_airspeed(),
      self()
    )

    ViaUtils.Process.start_loop(
      self(),
      controller_loop_interval_ms,
      @controller_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.commander_goals(), pilot_control_level, goals}, state) do
    # Logger.debug(
    #   "Controller goals rx: #{pilot_control_level}/#{state.pilot_control_level}: #{
    #     ViaUtils.Format.eftb_map(goals, 3)
    #   }"
    # )

    state =
      cond do
        pilot_control_level != CCT.pilot_control_level_speed_courserate_altituderate_sideslip() ->
          state

        state.pilot_control_level !=
            CCT.pilot_control_level_speed_courserate_altituderate_sideslip() ->
          Logger.warn(
            "latch to alt/course: #{ViaUtils.Format.eftb(state.altitude_m, 3)}/#{
              ViaUtils.Format.eftb_deg(state.course_rad, 1)
            }"
          )

          %{
            state
            | latch_course_rad: state.course_rad,
              latch_altitude_m: state.altitude_m,
              latch_command_time_prev_ms: :erlang.monotonic_time(:millisecond)
          }

        true ->
          current_time = :erlang.monotonic_time(:millisecond)
          dt = (current_time - state.latch_command_time_prev_ms) * 1.0e-3
          Logger

          latch_course_rad =
            (state.latch_course_rad + goals.course_rate_rps * dt)
            |> ViaUtils.Math.constrain_angle_to_compass()

          # Logger.debug("ground alt: #{ViaUtils.Format.eftb(state.ground_altitude_m, 3)}")

          latch_altitude_m =
            (state.latch_altitude_m + goals.altitude_rate_mps * dt)
            |> ViaUtils.Math.constrain(
              state.ground_altitude_m,
              state.ground_altitude_m + @agl_ceiling_m
            )

          %{
            state
            | latch_course_rad: latch_course_rad,
              latch_altitude_m: latch_altitude_m,
              latch_command_time_prev_ms: current_time
          }
      end

    ViaUtils.Process.detach_callback(state.clear_goals_timer)

    clear_goals_timer =
      ViaUtils.Process.attach_callback(
        self(),
        2 * state.controller_loop_interval_ms,
        @clear_goals_callback
      )

    {:noreply,
     %{
       state
       | pilot_control_level: pilot_control_level,
         goals_store: goals,
         clear_goals_timer: clear_goals_timer
     }}
  end

  @impl GenServer
  def handle_cast({Groups.remote_pilot_goals_override(), goals, goals_time_validity_ms}, state) do
    # Logger.debug(
    #   "Remote override (#{goals_time_validity_ms}ms) rx: #{ViaUtils.Format.eftb_map(goals, 3)}"
    # )

    ViaUtils.Process.detach_callback(state.clear_remote_pilot_override_timer)

    clear_remote_pilot_override_timer =
      ViaUtils.Process.attach_callback(
        self(),
        goals_time_validity_ms,
        @clear_remote_pilot_override_callback
      )

    {:noreply,
     %{
       state
       | remote_pilot_override: true,
         remote_pilot_goals_override: goals,
         clear_remote_pilot_override_timer: clear_remote_pilot_override_timer
     }}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude(), attitude_rad, _dt}, state) do
    # Logger.debug("ctrl att: #{ViaUtils.Format.eftb_map_deg(attitude_rad, 1)}")
    {:noreply, %{state | attitude_rad: attitude_rad}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.estimation_position_groundalt_groundspeed_course_airspeed(), position_rrm,
         ground_altitude_m, groundspeed_mps, course_rad, airspeed_mps, _dt},
        state
      ) do
    {:noreply,
     %{
       state
       | ground_altitude_m: ground_altitude_m,
         groundspeed_mps: groundspeed_mps,
         course_rad: course_rad,
         altitude_m: position_rrm.altitude_m,
         airspeed_mps: airspeed_mps
     }}
  end

  @impl GenServer
  def handle_info(@controller_loop, state) do
    if state.remote_pilot_override do
      goals = state.remote_pilot_goals_override
      Logger.warn("ctrl loop override/goals: #{ViaUtils.Format.eftb_map(goals, 3)}")
    else
      pilot_control_level = state.pilot_control_level
      goals = state.goals_store

      {pilot_control_level, goals} =
        if Enum.empty?(goals) do
          {state.default_pilot_control_level, state.default_goals}
        else
          {pilot_control_level, goals}
        end

      case pilot_control_level do
        CCT.pilot_control_level_speed_courserate_altituderate_sideslip() ->
          cmds = %{
            groundspeed_mps: goals.groundspeed_mps,
            sideslip_rad: goals.sideslip_rad,
            altitude_m: state.latch_altitude_m,
            course_rad: state.latch_course_rad
          }

          # Logger.debug("SCA cmds from rates: #{inspect(state.goals_store)}")
          Logger.debug("SCA cmds from rates: #{ViaUtils.Format.eftb_map(cmds, 3)}")
          Logger.debug("Calculate Attitude, then Bodyrates, then pass to companion")

        CCT.pilot_control_level_speed_course_altitude_sideslip() ->
          Logger.debug("SCA cmds: #{ViaUtils.Format.eftb_map(state.goals, 3)}")
          Logger.debug("Calculate Attitude, then Bodyrates, then pass to companion")

        CCT.pilot_control_level_roll_pitch_yawrate_throttle() ->
          Logger.debug("attitude. Calculate bodyrates, then pass to companion")

        CCT.pilot_control_level_rollrate_pitchrate_yawrate_throttle() ->
          Logger.debug("bodyrates: pass straight to companion")

        invalid_pcl ->
          raise "Commander has PCL of #{invalid_pcl}, which should not be possible"
      end

      # Logger.debug(
      #   "ctrl loop. pcl/goals: #{pilot_control_level} #{ViaUtils.Format.eftb_map(goals, 3)}"
      # )
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@clear_goals_callback, state) do
    Logger.debug("clear goals: #{inspect(state.goals_store)}")
    {:noreply, %{state | goals_store: %{}}}
  end

  @impl GenServer
  def handle_info(@clear_remote_pilot_override_callback, state) do
    Logger.debug("clear remote override")
    {:noreply, %{state | remote_pilot_override: false}}
  end
end
