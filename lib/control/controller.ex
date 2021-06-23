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

    {controller_modules, controllers} =
      Enum.reduce(Keyword.fetch!(config, :controllers), {%{}, %{}}, fn {pilot_control_level,
                                                                        pcl_config},
                                                                       {modules_acc,
                                                                        controllers_acc} ->
        controller_module = Keyword.fetch!(pcl_config, :module)
        controller_config = Keyword.fetch!(pcl_config, :controller_config)
        modules_acc = Map.put(modules_acc, pilot_control_level, controller_module)

        controllers_acc =
          Map.put(
            controllers_acc,
            pilot_control_level,
            apply(controller_module, :new, [controller_config])
          )

        {modules_acc, controllers_acc}
      end)

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
      vertical_velocity_mps: 0,
      altitude_m: 0,
      airspeed_mps: 0,
      attitude_rad: %{},
      controller_loop_interval_ms: controller_loop_interval_ms,
      clear_goals_timer: nil,
      clear_remote_pilot_override_timer: nil,
      controller_modules: controller_modules,
      controllers: controllers
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.commander_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.remote_pilot_goals_override(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude(), self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_groundalt_groundspeed_verticalvelocity_course_airspeed(),
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
          state

        state.pilot_control_level != CCT.pilot_control_level_4() ->
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
          dt_s = (current_time - state.latch_command_time_prev_ms) * 1.0e-3
          Logger

          latch_course_rad =
            (state.latch_course_rad + goals.course_rate_rps * dt_s)
            |> ViaUtils.Math.constrain_angle_to_compass()

          # Logger.debug("ground alt: #{ViaUtils.Format.eftb(state.ground_altitude_m, 3)}")

          latch_altitude_m =
            (state.latch_altitude_m + goals.altitude_rate_mps * dt_s)
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
        {Groups.estimation_position_groundalt_groundspeed_verticalvelocity_course_airspeed(),
         position_rrm, ground_altitude_m, groundspeed_mps, vertical_velocity_mps, course_rad,
         airspeed_mps, _dt},
        state
      ) do
    {:noreply,
     %{
       state
       | ground_altitude_m: ground_altitude_m,
         groundspeed_mps: groundspeed_mps,
         vertical_velocity_mps: vertical_velocity_mps,
         course_rad: course_rad,
         altitude_m: position_rrm.altitude_m,
         airspeed_mps: airspeed_mps
     }}
  end

  @impl GenServer
  def handle_info(@controller_loop, state) do
    state =
      if state.remote_pilot_override do
        goals = state.remote_pilot_goals_override
        Logger.warn("ctrl loop override/goals: #{ViaUtils.Format.eftb_map(goals, 3)}")
        state
      else
        pilot_control_level = state.pilot_control_level
        goals = state.goals_store

        {pilot_control_level, goals} =
          if Enum.empty?(goals) do
            {state.default_pilot_control_level, state.default_goals}
          else
            {pilot_control_level, goals}
          end

        process_commands(pilot_control_level, goals, state)
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

  @spec process_commands(integer(), map(), map()) :: map()
  def process_commands(pilot_control_level, goals, state) do
    case pilot_control_level do
      CCT.pilot_control_level_4() ->
        pcl_3_cmds = %{
          groundspeed_mps: goals.groundspeed_mps,
          sideslip_rad: goals.sideslip_rad,
          altitude_m: state.latch_altitude_m,
          course_rad: state.latch_course_rad
        }

        Logger.debug("SCA cmds from rates: #{ViaUtils.Format.eftb_map(pcl_3_cmds, 3)}")
        process_commands(
          CCT.pilot_control_level_3(),
          pcl_3_cmds,
          state
        )

      CCT.pilot_control_level_3() ->
        Logger.debug("SCA cmds: #{ViaUtils.Format.eftb_map(goals, 3)}")

        values =
          Map.take(state, [:groundspeed_mps, :vertical_velocity_mps, :altitude_m, :course_rad])
          |> Map.put(:yaw_rad, state.attitude_rad.yaw_rad)

        unless Enum.empty?(values) do
          controllers = state.controllers

          {pcl_3_controller, pcl_2_cmds} =
            apply(get_in(state, [:controller_modules, CCT.pilot_control_level_3()]), :update, [
              Map.get(controllers, CCT.pilot_control_level_3()),
              goals,
              values,
              state.airspeed_mps,
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
        else
          state
        end

      CCT.pilot_control_level_2() ->
        Logger.debug("attitude. Calculate bodyrates, then pass to companion")
        values = state.attitude_rad

        unless Enum.empty?(values) do
          controllers = state.controllers

          {pcl_2_controller, pcl_1_cmds} =
            apply(get_in(state, [:controller_modules, CCT.pilot_control_level_2()]), :update, [
              Map.get(controllers, CCT.pilot_control_level_2()),
              goals,
              values,
              state.airspeed_mps,
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
        else
          state
        end

      CCT.pilot_control_level_1() ->
        Logger.debug("bodyrates: pass straight to companion")
        state

      invalid_pcl ->
        raise "Commander has PCL of #{invalid_pcl}, which should not be possible"
    end
  end
end
