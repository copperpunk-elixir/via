defmodule Command.Commander do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.Sorters, as: Sorters
  require Command.ControlTypes, as: CCT
  require MessageSorter.Sorter
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog


  @commander_loop :commander_loop
  @clear_values_callback :clear_values_callback
  @goals :goals
  def start_link(config) do
    Logger.debug("Start Command.Commander GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(_config) do

    state = %{
      goals: %{},
      goal_restrictions: %{},
      pilot_control_level: nil,
      goals_watchdog: Watchdog.new({@clear_values_callback, @goals}, 2*LoopIntervals.commander_goals_publish_ms),
    }

    Comms.Supervisor.start_operator(__MODULE__)

    MessageSorter.Sorter.register_for_sorter_current_and_stale(
      Sorters.pilot_control_level_and_goals(),
      :value,
      LoopIntervals.commander_goals_publish_ms()
    )

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.commander_goals_publish_ms,
      @commander_loop
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
        {Groups.message_sorter_value(), Sorters.pilot_control_level_and_goals(), _classification,
         {pilot_control_level, goals}, _status},
        state
      ) do

   goals_watchdog = Watchdog.reset(state.goals_watchdog)

    # Logger.debug("Goals sorter rx: #{pilot_control_level}: #{ViaUtils.Format.eftb_map(goals, 3)}")
    {:noreply,
     %{
       state
       | pilot_control_level: pilot_control_level,
         goals: goals,
         goals_watchdog: goals_watchdog
     }}
  end

  @impl GenServer
  def handle_info(@commander_loop, state) do
    pilot_control_level = state.pilot_control_level
    goals = state.goals

    if !is_nil(goals) do
      goals =
        update_goals_to_reflect_goal_restrictions(
          goals,
          state.goal_restrictions,
          pilot_control_level
        )

      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {Groups.commander_goals(), pilot_control_level, goals},
        self()
      )

      # Logger.debug("cmdr loop. pcl/goals: #{pilot_control_level}/#{inspect(goals)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_values_callback, key}, state) do
    Logger.debug("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, %{})}
  end

  @spec update_goals_to_reflect_goal_restrictions(map(), map(), integer()) :: map()
  def update_goals_to_reflect_goal_restrictions(goals, _goal_restrictions, pilot_control_level) do
    # This function currently just passes on the goals, without considering the goal restrictions
    if pilot_control_level == CCT.pilot_control_level_3() or
         pilot_control_level == CCT.pilot_control_level_4() do
      # Take goal_restrictions into account
      goals
    else
      goals
    end
  end
end
