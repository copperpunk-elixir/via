defmodule Control.Controller do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require MessageSorter.Sorter
  require ViaUtils.Shared.ControlTypes, as: CCT
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @controller_loop :controller_loop
  @commands :commands
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
      default_commands: Keyword.fetch!(config, :default_commands),
      commands: %{},
      pilot_control_level: nil,
      remote_pilot_override_commands: %{},
      latch_values: %{},
      position: %{},
      velocity: %{},
      attitude: %{},
      agl_ceiling_m: Keyword.fetch!(config, :agl_ceiling_m),
      commands_watchdog:
        Watchdog.new(
          {@clear_values_map_callback, @commands},
          2 * LoopIntervals.commands_publish_ms()
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

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.current_commands_for_pilot_control_level(),
      self()
    )

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
  def handle_cast(
        {Groups.current_commands_for_pilot_control_level(), pilot_control_level, commands},
        state
      ) do
    # Logger.debug(
    #   "Ctrl cmds rx: #{pilot_control_level}/#{state.pilot_control_level}: #{ViaUtils.Format.eftb_map(commands.current_pcl, 3)}"
    # )

    # Logger.debug(
    #       "Ctrl cmds rx (all): #{ViaUtils.Format.eftb_map(commands.any_pcl, 3)}"
    #     )
    state =
      cond do
        pilot_control_level != CCT.pilot_control_level_4() ->
          %{
            state
            | commands: %{pilot_control_level => commands.current_pcl, any_pcl: commands.any_pcl},
              pilot_control_level: pilot_control_level
          }

        state.pilot_control_level != CCT.pilot_control_level_4() ->
          latch_values =
            Map.take(state.position, [:altitude_m])
            |> Map.merge(Map.take(state.velocity, [:course_rad]))
            |> Map.put(:command_time_prev_ms, :erlang.monotonic_time(:millisecond))

          # Logger.debug("latch values: #{inspect(latch_values)}")
          if Enum.count(latch_values) == 3 do
            Logger.warn(
              "latch to alt/course: #{ViaUtils.Format.eftb(latch_values.altitude_m, 3)}/#{ViaUtils.Format.eftb_deg(latch_values.course_rad, 1)}"
            )

            %{
              state
              | commands: %{pilot_control_level => commands.current_pcl, any_pcl: commands.any_pcl},
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

          latch_course_rad =
            (latch_values.course_rad + commands.current_pcl.course_rate_rps * dt_s)
            |> ViaUtils.Math.constrain_angle_to_compass()

          ground_altitude_m = state.position.ground_altitude_m

          latch_altitude_m =
            (latch_values.altitude_m + commands.current_pcl.altitude_rate_mps * dt_s)
            |> ViaUtils.Math.constrain(
              ground_altitude_m,
              ground_altitude_m + state.agl_ceiling_m
            )

          %{
            state
            | pilot_control_level: pilot_control_level,
              commands: %{pilot_control_level => commands.current_pcl, any_pcl: commands.any_pcl},
              latch_values: %{
                course_rad: latch_course_rad,
                altitude_m: latch_altitude_m,
                command_time_prev_ms: current_time
              }
          }

        true ->
          state
      end

    commands_watchdog = Watchdog.reset(state.commands_watchdog)

    {:noreply,
     %{
       state
       | commands_watchdog: commands_watchdog
     }}
  end

  @impl GenServer
  def handle_cast(
        {Groups.remote_pilot_override_commands(), override_commands},
        state
      ) do
    # Logger.debug("Remote override rx: #{ViaUtils.Format.eftb_map(override_commands, 3)}")

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
        commands = Map.get(state, :commands, %{})

        {pilot_control_level, commands} =
          if map_size(commands) == 0 do
            {state.default_pilot_control_level,
             %{state.default_pilot_control_level => state.default_commands}}
          else
            {pilot_control_level, commands}
          end

        # Logger.debug("ctrl loop. pcl/cmds: #{inspect(pilot_control_level)}/#{inspect(commands)}")

        any_pcl_commands = Map.get(commands, :any_pcl, %{})

        send_commands_for_any_pcl(any_pcl_commands)

        case pilot_control_level do
          CCT.pilot_control_level_4() ->
            process_pcl_4_commands(Map.put(state, :commands, commands))

          CCT.pilot_control_level_3() ->
            process_pcl_3_commands(Map.put(state, :commands, commands))

          CCT.pilot_control_level_2() ->
            process_pcl_2_commands(Map.put(state, :commands, commands))

          CCT.pilot_control_level_1() ->
            process_pcl_1_commands(Map.put(state, :commands, commands))

          other ->
            Logger.error("Unknown pilot_control_level: #{inspect(other)}")
            state
        end
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_values_map_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, %{})}
  end

  def process_pcl_4_commands(state) do
    commands = state.commands
    pcl_4_commands = Map.get(commands, CCT.pilot_control_level_4(), %{})
    # Logger.debug("pcl4 goals: #{ViaUtils.Format.eftb_map(pcl_4_commands, 3)}")

    pcl_3_cmds =
      Map.take(pcl_4_commands, [:groundspeed_mps, :sideslip_rad])
      |> Map.merge(Map.take(state.latch_values, [:altitude_m, :course_rad]))

    if Enum.count(pcl_3_cmds) >= 4 do
      # Logger.debug("SCA cmds from rates: #{ViaUtils.Format.eftb_map(pcl_3_cmds, 3)}")
      state = %{state | commands: Map.put(commands, CCT.pilot_control_level_3(), pcl_3_cmds)}
      process_pcl_3_commands(state)
    else
      state
    end
  end

  def process_pcl_3_commands(state) do
    commands = state.commands
    pcl_3_commands = Map.get(commands, CCT.pilot_control_level_3(), %{})

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
      # Logger.debug("SCA cmds (pcl): #{ViaUtils.Format.eftb_map(pcl_3_commands, 3)}")
      # Logger.debug("SCA vals: #{ViaUtils.Format.eftb_map(values, 3)}")
      controllers = state.controllers
      controller = Map.get(controllers, CCT.pilot_control_level_3())

      {pcl_3_controller, pcl_2_cmds} =
        apply(controller.__struct__, :update, [
          controller,
          pcl_3_commands,
          values,
          velocity.airspeed_mps,
          LoopIntervals.controller_update_ms() * 1.0e-3
        ])

      thrust_cmd_scaled =
        if pcl_3_commands.groundspeed_mps < 1.0, do: 0, else: pcl_2_cmds.thrust_scaled

      pcl_2_cmds = Map.put(pcl_2_cmds, :thrust_scaled, thrust_cmd_scaled)
      # Logger.debug("SCA cmds from rates: #{inspect(state.goals_store)}")
      # Logger.debug("Calculate Attitude, then Bodyrates, then pass to companion")
      controllers = Map.put(controllers, CCT.pilot_control_level_3(), pcl_3_controller)
      # Logger.debug("output: #{ViaUtils.Format.eftb_map(pcl_2_cmds, 3)}")
      state = %{
        state
        | controllers: controllers,
          commands: Map.put(commands, CCT.pilot_control_level_2(), pcl_2_cmds)
      }

      process_pcl_2_commands(state)
    else
      state
    end
  end

  def process_pcl_2_commands(state) do
    commands = state.commands
    pcl_2_commands = Map.get(state.commands, CCT.pilot_control_level_2(), %{})

    values = state.attitude

    if map_size(values) > 0 do
      # Logger.debug(
      #   "attitude. Calculate bodyrates, then pass to companion: #{ViaUtils.Format.eftb_map(pcl_2_commands, 3)}"
      # )

      controllers = state.controllers
      controller = Map.get(controllers, CCT.pilot_control_level_2())

      {pcl_2_controller, pcl_1_cmds} =
        apply(controller.__struct__, :update, [
          controller,
          pcl_2_commands,
          values,
          Map.get(state.velocity, :airspeed_mps, 0),
          LoopIntervals.controller_update_ms() * 1.0e-3
        ])

      controllers = Map.put(controllers, CCT.pilot_control_level_2(), pcl_2_controller)
      # commands = Map.put()
      # Logger.debug("output: #{ViaUtils.Format.eftb_map(pcl_1_cmds, 3)}")
      state = %{
        state
        | controllers: controllers,
          commands: Map.put(commands, CCT.pilot_control_level_1(), pcl_1_cmds)
      }

      process_pcl_1_commands(state)
    else
      state
    end
  end

  def process_pcl_1_commands(state) do
    # Logger.debug("bodyrates: send to companion: #{ViaUtils.Format.eftb_map(get_in(state, [:commands, 1, :current_pcl]), 3)}")
    # Logger.debug("proc pcl 1: #{inspect(state.commands)}")
    pcl_1_commands = Map.get(state.commands, CCT.pilot_control_level_1(), %{})

    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.controller_bodyrate_commands(), pcl_1_commands},
      self()
    )

    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.current_pilot_control_level_and_commands(), state.pilot_control_level,
       state.commands},
      self()
    )

    state
  end

  @spec send_commands_for_any_pcl(map()) :: atom()
  def send_commands_for_any_pcl(any_pcl_commands) do
    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.commands_for_any_pilot_control_level(), any_pcl_commands},
      self()
    )
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
