defmodule Command.Commander do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.Sorters, as: Sorters
  require Command.ControlTypes, as: CCT
  require MessageSorter.Sorter

  def start_link(config) do
    Logger.debug("Start Command.Commander GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    {default_pilot_control_level, default_goals} =
      Keyword.fetch!(config, :default_goals) |> Map.to_list() |> Enum.at(0)

    state = %{
      default_pilot_control_level: default_pilot_control_level,
      default_goals: default_goals,
      goals_store: %{},
      goal_restrictions_store: %{},
      pilot_control_level: default_pilot_control_level
    }

    commander_loop_interval_ms = Keyword.fetch!(config, :commander_loop_interval_ms)
    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.dt_accel_gyro_val(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.gps_itow_position_velocity(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.goals_sorter(), self())

    Enum.each(
      CCT.pilot_control_level_rollrate_pitchrate_yawrate_throttle()..CCT.pilot_control_level_speed_course_altitude_sideslip(),
      fn pilot_control_level ->
        MessageSorter.Sorter.register_for_sorter_current_only(
          {Sorters.goals(), pilot_control_level},
          :value,
          commander_loop_interval_ms
        )
      end
    )

    MessageSorter.Sorter.register_for_sorter_current_and_stale(
      Sorters.pilot_control_level(),
      :value,
      commander_loop_interval_ms
    )

    ViaUtils.Process.start_loop(
      self(),
      commander_loop_interval_ms,
      :commander_loop
    )

    ViaUtils.Process.start_loop(
      self(),
      2 * commander_loop_interval_ms,
      :clear_goals_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast(
        {Groups.goals_sorter(), classification, time_validity_ms, {goals, pilot_control_level}},
        state
      ) do
    # Logger.debug("nav rx: class/time/goals: #{inspect(classification)}/#{time_validity_ms}/#{ViaUtils.Format.eftb_map(goals, 3)}")

    MessageSorter.Sorter.add_message(
      {Sorters.goals(), pilot_control_level},
      classification,
      time_validity_ms,
      goals
    )

    MessageSorter.Sorter.add_message(
      Sorters.pilot_control_level(),
      classification,
      time_validity_ms,
      pilot_control_level
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {Groups.message_sorter_value(), {Sorters.goals(), pilot_control_level}, _classification,
         goals, MessageSorter.Sorter.status_current()},
        state
      ) do
    goals_store = Map.put(state.goals_store, pilot_control_level, goals)

    # Logger.debug("Goals sorter rx: #{pilot_control_level}: #{ViaUtils.Format.eftb_map(goals, 3)}")
    {:noreply, %{state | goals_store: goals_store}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.message_sorter_value(), Sorters.pilot_control_level(), _classification,
         pilot_control_level, _status},
        state
      ) do
    # Logger.warn("PCL sorter rx: #{pilot_control_level}/#{inspect(status)}")
    {:noreply, %{state | pilot_control_level: pilot_control_level}}
  end

  @impl GenServer
  def handle_info(:commander_loop, state) do
    pilot_control_level = state.pilot_control_level
    goals = Map.get(state.goals_store, pilot_control_level)

    {goals, status} =
      if is_nil(goals) do
        {update_goals_to_reflect_goal_restrictions(
           state.default_goals,
           state.goal_restrictions_store,
           pilot_control_level
         ), :default}
      else
        {goals, :current}
      end

    ViaUtils.Comms.send_local_msg_to_group(__MODULE__, {Groups.commander_goals(), pilot_control_level, goals}, self())
    # Logger.debug("cmdr loop. #{inspect(status)} pcl/goals: #{pilot_control_level}/#{inspect(goals)}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:clear_goals_loop, state) do
    # Logger.debug("clear goals: #{inspect(state.goals_store)}")
    {:noreply, %{state | goals_store: %{}}}
  end

  @spec update_goals_to_reflect_goal_restrictions(map(), map(), integer()) :: map()
  def update_goals_to_reflect_goal_restrictions(goals, _goal_restrictions, pilot_command_level) do
    # This function currently just passes on the goals, without considering the goal restrictions
    if pilot_command_level ==
         Command.ControlTypes.pilot_control_level_speed_courserate_altituderate_sideslip() or
         pilot_command_level ==
           Command.ControlTypes.pilot_control_level_speed_course_altitude_sideslip() do
      # Take goal_restrictions into account
      goals
    else
      goals
    end
  end
end
