defmodule Control.Controller do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require MessageSorter.Sorter
  require Command.ControlTypes, as: CCT
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @controller_loop :controller_loop
  @goals :goals
  @attitude :attitude
  @position_velocity :position_velocity
  @remote_pilot_override_commands :remote_pilot_override_commands
  @clear_values_map_callback :clear_values_map_callback

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    state = %{
      default_pilot_control_level: Keyword.fetch!(config, :default_pilot_control_level),
      default_goals: Keyword.fetch!(config, :default_goals),
      goals: %{},
      pilot_control_level: nil,
      remote_pilot_override_commands: %{},
      latch_values: %{},
      position: %{},
      velocity: %{},
      attitude: %{},
      agl_ceiling_m: Keyword.fetch!(config, :agl_ceiling_m),
      goals_watchdog:
        Watchdog.new(
          {@clear_values_map_callback, @goals},
          2 * LoopIntervals.commander_goals_publish_ms()
        ),
      remote_pilot_override_commands_watchdog:
        Watchdog.new(
          {@clear_values_map_callback, @remote_pilot_override_commands},
          2 * LoopIntervals.remote_pilot_goals_publish_ms()
        ),
      attitude_watchdog:
        Watchdog.new(
          {@clear_values_map_callback, @attitude},
          2 * LoopIntervals.attitude_publish_ms()
        ),
      position_velocity_watchdog:
        Watchdog.new(
          {@clear_values_map_callback, @position_velocity},
          2 * LoopIntervals.position_velocity_publish_ms()
        ),
      controllers: get_controllers_from_config(config)
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.commander_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.remote_pilot_override_commands(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity(), self())

    ViaUtils.Process.start_loop(self(), LoopIntervals.controller_update_ms(), @controller_loop)
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude(), attitude}, state) do
    attitude_watchdog = Watchdog.reset(state.attitude_watchdog)
    {:noreply, %{state | attitude: attitude, attitude_watchdog: attitude_watchdog}}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_position_velocity(), position, velocity}, state) do
    position_velocity_watchdog = Watchdog.reset(state.position_velocity_watchdog)

    {:noreply,
     %{
       state
       | position: position,
         velocity: velocity,
         position_velocity_watchdog: position_velocity_watchdog
     }}
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
        pilot_control_level != CCT.pilot_control_level_4() ->
          %{state | goals: goals, pilot_control_level: pilot_control_level}

        state.pilot_control_level != CCT.pilot_control_level_4() ->
          latch_values =
            Map.take(state.position, [:altitude_m])
            |> Map.merge(Map.take(state.velocity, [:course_rad]))
            |> Map.put(:command_time_prev_ms, :erlang.monotonic_time(:millisecond))

          # Logger.debug("latch values: #{inspect(latch_values)}")
          if Enum.count(latch_values) == 3 do
            Logger.warn(
              "latch to alt/course: #{ViaUtils.Format.eftb(latch_values.altitude_m, 3)}/#{
                ViaUtils.Format.eftb_deg(latch_values.course_rad, 1)
              }"
            )

            %{
              state
              | goals: goals,
                latch_values: latch_values,
                pilot_control_level: pilot_control_level
            }
          else
            # We do not have position_velocity values, so do not latch yet
            Logger.warn("Attempting to latch, but no Position/Velocity values available")
            state
          end

        map_size(state.position) > 0 ->
          # pilot_control_level == CCT.pilot_control_level_4 and has since the last loop,
          # i.e., it did not just change
          # Therefore we know that the latch values are populated
          latch_values = state.latch_values
          current_time = :erlang.monotonic_time(:millisecond)
          dt_s = (current_time - latch_values.command_time_prev_ms) * 1.0e-3
          Logger

          latch_course_rad =
            (latch_values.course_rad + goals.course_rate_rps * dt_s)
            |> ViaUtils.Math.constrain_angle_to_compass()

          ground_altitude_m = state.position.ground_altitude_m

          latch_altitude_m =
            (latch_values.altitude_m + goals.altitude_rate_mps * dt_s)
            |> ViaUtils.Math.constrain(
              ground_altitude_m,
              ground_altitude_m + state.agl_ceiling_m
            )

          %{
            state
            | pilot_control_level: pilot_control_level,
              goals: goals,
              latch_values: %{
                course_rad: latch_course_rad,
                altitude_m: latch_altitude_m,
                command_time_prev_ms: current_time
              }
          }

        true ->
          state
      end

    goals_watchdog = Watchdog.reset(state.goals_watchdog)

    {:noreply,
     %{
       state
       | goals_watchdog: goals_watchdog
     }}
  end

  @impl GenServer
  def handle_cast(
        {Groups.remote_pilot_override_commands(), override_commands},
        state
      ) do
    # Logger.debug(
    #   "Remote override (#{goals_time_validity_ms}ms) rx: #{ViaUtils.Format.eftb_map(goals, 3)}"
    # )

    remote_pilot_override_commands_watchdog =
      Watchdog.reset(state.remote_pilot_override_commands_watchdog)

    {:noreply,
     %{
       state
       | remote_pilot_override_commands: override_commands,
         remote_pilot_override_commands_watchdog: remote_pilot_override_commands_watchdog
     }}
  end

  @impl GenServer
  def handle_info(@controller_loop, state) do
    override_commands = state.remote_pilot_override_commands

    state =
      if map_size(override_commands) > 0 do
        # Send values straight to companion
        # Logger.warn(
        #   "ctrl loop override_commands: #{ViaUtils.Format.eftb_map(override_commands, 3)}"
        # )

        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          {Groups.controller_override_commands(), override_commands},
          self()
        )

        state
      else
        pilot_control_level = state.pilot_control_level
        goals = state.goals

        {pilot_control_level, goals} =
          if map_size(goals) == 0 do
            {state.default_pilot_control_level,
             Map.get(state.default_goals, state.default_pilot_control_level)}
          else
            {pilot_control_level, goals}
          end

        # Logger.debug(
        #   "ctrl loop. pcl/goals: #{inspect(pilot_control_level)}/#{
        #     ViaUtils.Format.eftb_map(goals, 3)
        #   }"
        # )
        process_commands(pilot_control_level, goals, state)
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_values_map_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, %{})}
  end

  @spec process_commands(integer(), map(), map()) :: map()
  def process_commands(_pilot_control_level, goals, state) when map_size(goals) == 0 do
    state
  end

  def process_commands(pilot_control_level, goals, state)
      when pilot_control_level == CCT.pilot_control_level_4() do
    pcl_3_cmds =
      Map.take(goals, [:groundspeed_mps, :sideslip_rad])
      |> Map.merge(Map.take(state.latch_values, [:altitude_m, :course_rad]))

    if Enum.count(pcl_3_cmds) == 4 do
      Logger.debug("SCA cmds from rates: #{ViaUtils.Format.eftb_map(pcl_3_cmds, 3)}")

      process_commands(
        CCT.pilot_control_level_3(),
        pcl_3_cmds,
        state
      )
    else
      state
    end
  end

  def process_commands(pilot_control_level, goals, state)
      when pilot_control_level == CCT.pilot_control_level_3() do
    velocity = state.velocity

    values =
      Map.take(velocity, [
        :groundspeed_mps,
        :vertical_velocity_mps,
        :course_rad
      ])
      |> Map.merge(Map.take(state.position, [:altitude_m]))
      |> Map.merge(Map.take(state.attitude, [:yaw_rad]))

    if Enum.count(values) == 5 do
      Logger.debug("SCA cmds: #{ViaUtils.Format.eftb_map(goals, 3)}")
      controllers = state.controllers
      controller = Map.get(controllers, CCT.pilot_control_level_3())

      {pcl_3_controller, pcl_2_cmds} =
        apply(controller.__struct__, :update, [
          controller,
          goals,
          values,
          velocity.airspeed_mps,
          LoopIntervals.controller_update_ms() * 1.0e-3
        ])

      thrust_cmd_scaled = if goals.groundspeed_mps < 1.0, do: 0, else: pcl_2_cmds.thrust_scaled

      pcl_2_cmds = Map.put(pcl_2_cmds, :thrust_scaled, thrust_cmd_scaled)
      # Logger.debug("SCA cmds from rates: #{inspect(state.goals_store)}")
      Logger.debug("Calculate Attitude, then Bodyrates, then pass to companion")
      controllers = Map.put(controllers, CCT.pilot_control_level_3(), pcl_3_controller)
      Logger.debug("output: #{ViaUtils.Format.eftb_map(pcl_2_cmds, 3)}")
      state = %{state | controllers: controllers}

      process_commands(
        CCT.pilot_control_level_2(),
        pcl_2_cmds,
        state
      )
    else
      state
    end
  end

  def process_commands(pilot_control_level, goals, state)
      when pilot_control_level == CCT.pilot_control_level_2() do
    values = state.attitude

    if map_size(values) > 0 do
      Logger.debug("attitude. Calculate bodyrates, then pass to companion")
      controllers = state.controllers
      controller = Map.get(controllers, CCT.pilot_control_level_2())

      {pcl_2_controller, pcl_1_cmds} =
        apply(controller.__struct__, :update, [
          controller,
          goals,
          values,
          Map.get(state.velocity, :airspeed_mps, 0),
          LoopIntervals.controller_update_ms() * 1.0e-3
        ])

      controllers = Map.put(controllers, CCT.pilot_control_level_2(), pcl_2_controller)
      Logger.debug("output: #{ViaUtils.Format.eftb_map(pcl_1_cmds, 3)}")
      state = %{state | controllers: controllers}

      process_commands(
        CCT.pilot_control_level_1(),
        pcl_1_cmds,
        state
      )
    else
      state
    end
  end

  def process_commands(pilot_control_level, goals, state)
      when pilot_control_level == CCT.pilot_control_level_1() do
    Logger.debug("bodyrates: send to companion")

    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.controller_bodyrate_goals(), goals},
      self()
    )

    state
  end

  def process_commands(pilot_control_level, _goals, _state) do
    raise "Commander has PCL of #{inspect(pilot_control_level)}, which should not be possible"
  end

  @spec get_controllers_from_config(list()) :: map()
  def get_controllers_from_config(config) do
    Enum.reduce(Keyword.fetch!(config, :controllers), %{}, fn {pilot_control_level, pcl_config},
                                                              controllers_acc ->
      controller_module = Keyword.fetch!(pcl_config, :module)
      controller_config = Keyword.fetch!(pcl_config, :controller_config)

      Map.put(
        controllers_acc,
        pilot_control_level,
        apply(controller_module, :new, [controller_config])
      )
    end)
  end
end
