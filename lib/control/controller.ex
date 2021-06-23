defmodule Control.Controller do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require MessageSorter.Sorter
  require Command.ControlTypes, as: CCT

  @controller_loop :controller_loop
  # @clear_goals_callback :clear_goals_callback
  # @clear_attitude_callback :clear_attitude_callback
  # @clear_position_velocity_callback :clear_position_velocity_callback
  # @clear_remote_pilot_override_callback :clear_remote_pilot_override_callback
  @clear_values_callback :clear_values_callback
  @agl_ceiling_m 150.0

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    controller_loop_interval_ms = Keyword.fetch!(config, :controller_loop_interval_ms)
    controllers = get_controllers_from_config(config)

    state = %{
      default_pilot_control_level: Keyword.fetch!(config, :default_pilot_control_level),
      default_goals: Keyword.fetch!(config, :default_goals),
      goals: %{},
      pilot_control_level: nil,
      remote_pilot_override_commands: %{},
      latch_values: %{},
      # latch_course_rad: 0,
      # latch_altitude_m: 0,
      # latch_command_time_prev_ms: 0,
      position_velocity: %{},
      # ground_altitude_m: 0,
      # course_rad: 0,
      # groundspeed_mps: 0,
      # vertical_velocity_mps: 0,
      # altitude_m: 0,
      # airspeed_mps: 0,
      attitude: %{},
      controller_loop_interval_ms: controller_loop_interval_ms,
      clear_goals_timer: nil,
      clear_remote_pilot_override_commands_timer: nil,
      clear_attitude_timer: nil,
      clear_position_velocity_timer: nil,
      controllers: controllers
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.commander_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.remote_pilot_override_commands(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude(), self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_velocity(),
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
        pilot_control_level != CCT.pilot_control_level_4() ->
          %{state | goals: goals, pilot_control_level: pilot_control_level}

        state.pilot_control_level != CCT.pilot_control_level_4() ->
          position_velocity = state.position_velocity
          position = Map.get(position_velocity, :position_rrm, %{})

          latch_values =
            Map.take(position, [:altitude_m])
            |> Map.merge(Map.take(position_velocity, [:course_rad]))
            |> Map.put(:command_time_prev_ms, :erlang.monotonic_time(:millisecond))

          # Logger.debug("latch values: #{inspect(latch_values)}")
          if Enum.count(latch_values) != 3 do
            # We do not have position_velocity values, so do not latch yet
            Logger.warn("Attempting to latch, but no Position/Velocity values available")
            state
          else
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
          end

        !Enum.empty?(state.position_velocity) ->
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

          # Logger.debug("ground alt: #{ViaUtils.Format.eftb(state.ground_altitude_m, 3)}")

          ground_altitude_m = state.position_velocity.ground_altitude_m

          latch_altitude_m =
            (latch_values.altitude_m + goals.altitude_rate_mps * dt_s)
            |> ViaUtils.Math.constrain(
              ground_altitude_m,
              ground_altitude_m + @agl_ceiling_m
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

    clear_goals_timer =
      ViaUtils.Process.reattach_timer(
        state.clear_goals_timer,
        2 * state.controller_loop_interval_ms,
        {@clear_values_callback, :goals}
      )

    {:noreply,
     %{
       state
       | clear_goals_timer: clear_goals_timer
     }}
  end

  @impl GenServer
  def handle_cast(
        {Groups.remote_pilot_override_commands(), override_commands, time_validity_ms},
        state
      ) do
    # Logger.debug(
    #   "Remote override (#{goals_time_validity_ms}ms) rx: #{ViaUtils.Format.eftb_map(goals, 3)}"
    # )

    clear_remote_pilot_override_commands_timer =
      ViaUtils.Process.reattach_timer(
        state.clear_remote_pilot_override_commands_timer,
        time_validity_ms,
        {@clear_values_callback, :remote_pilot_override_commands}
      )

    {:noreply,
     %{
       state
       | remote_pilot_override_commands: override_commands,
         clear_remote_pilot_override_commands_timer: clear_remote_pilot_override_commands_timer
     }}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude(), attitude_rad, dt_s}, state) do
    # Logger.debug("ctrl att: #{ViaUtils.Format.eftb_map_deg(attitude_rad, 1)}")
    clear_attitude_timer =
      ViaUtils.Process.reattach_timer(
        state.clear_attitude_timer,
        2 * round(dt_s * 1000),
        {@clear_values_callback, :attitude}
      )

    {:noreply, %{state | attitude: attitude_rad, clear_attitude_timer: clear_attitude_timer}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.estimation_position_velocity(), position_velocity, dt_s},
        state
      ) do
    clear_position_velocity_timer =
      ViaUtils.Process.reattach_timer(
        state.clear_position_velocity_timer,
        2 * round(dt_s * 1000),
        {@clear_values_callback, :position_velocity}
      )

    {:noreply,
     %{
       state
       | position_velocity: position_velocity,
         clear_position_velocity_timer: clear_position_velocity_timer
     }}
  end

  @impl GenServer
  def handle_info(@controller_loop, state) do
    override_commands = state.remote_pilot_override_commands

    state =
      if !Enum.empty?(override_commands) do
        # Send values straight to companion
        Logger.warn(
          "ctrl loop override_commands: #{ViaUtils.Format.eftb_map(override_commands, 3)}"
        )

        state
      else
        pilot_control_level = state.pilot_control_level
        goals = state.goals

        {pilot_control_level, goals} =
          if Enum.empty?(goals) do
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
  def handle_info({@clear_values_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, %{})}
  end

  # @impl GenServer
  # def handle_info(@clear_remote_pilot_override_callback, state) do
  #   Logger.debug("clear remote override")
  #   {:noreply, %{state | remote_pilot_override: false}}
  # end

  # @impl GenServer
  # def handle_info(@clear_goals_callback, state) do
  #   Logger.debug("clear goals: #{inspect(state.goals)}")
  #   {:noreply, %{state | goals_store: %{}}}
  # end

  @spec process_commands(integer(), map(), map()) :: map()
  def process_commands(pilot_control_level, goals, state) do
    if Enum.empty?(goals) do
      state
    else
      case pilot_control_level do
        CCT.pilot_control_level_4() ->
          pcl_3_cmds =
            Map.take(goals, [:groundspeed_mps, :sideslip_rad])
            |> Map.merge(Map.take(state.latch_values, [:altitude_m, :course_rad]))

          Logger.debug("SCA cmds from rates: #{ViaUtils.Format.eftb_map(pcl_3_cmds, 3)}")

          if Enum.count(pcl_3_cmds) == 4 do
            process_commands(
              CCT.pilot_control_level_3(),
              pcl_3_cmds,
              state
            )
          else
            state
          end

        CCT.pilot_control_level_3() ->
          Logger.debug("SCA cmds: #{ViaUtils.Format.eftb_map(goals, 3)}")
          position_velocity = state.position_velocity
          position =  Map.get(position_velocity, :position_rrm, %{})
          values =
            Map.take(position_velocity, [
              :groundspeed_mps,
              :vertical_velocity_mps,
              :course_rad
            ])
            |> Map.merge(Map.take(position, [:altitude_m]))
            |> Map.merge(Map.take(state.attitude, [:yaw_rad]))


          if Enum.count(values) != 5 do
            state
          else
            controllers = state.controllers
            controller = Map.get(controllers, CCT.pilot_control_level_3())

            {pcl_3_controller, pcl_2_cmds} =
              apply(controller.__struct__, :update, [
                controller,
                goals,
                values,
                position_velocity.airspeed_mps,
                state.controller_loop_interval_ms * 1.0e-3
              ])

            throttle_cmd_scaled =
              if goals.groundspeed_mps < 1.0, do: 0, else: pcl_2_cmds.throttle_scaled

            pcl_2_cmds = Map.put(pcl_2_cmds, :throttle_scaled, throttle_cmd_scaled)
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
          end

        CCT.pilot_control_level_2() ->
          Logger.debug("attitude. Calculate bodyrates, then pass to companion")
          values = state.attitude

          if Enum.empty?(values) do
            state
          else
            controllers = state.controllers
            controller = Map.get(controllers, CCT.pilot_control_level_2())

            {pcl_2_controller, pcl_1_cmds} =
              apply(controller.__struct__, :update, [
                controller,
                goals,
                values,
                Map.get(state.position_velocity, :airspeed_mps, 0),
                state.controller_loop_interval_ms * 1.0e-3
              ])

            controllers = Map.put(controllers, CCT.pilot_control_level_2(), pcl_2_controller)
            Logger.debug("output: #{ViaUtils.Format.eftb_map(pcl_1_cmds, 3)}")
            state = %{state | controllers: controllers}

            process_commands(
              CCT.pilot_control_level_1(),
              pcl_1_cmds,
              state
            )
          end

        CCT.pilot_control_level_1() ->
          Logger.debug("bodyrates: Convert to [-1, 1] range and send to companion")
          state

        invalid_pcl ->
          raise "Commander has PCL of #{inspect(invalid_pcl)}, which should not be possible"
      end
    end
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
