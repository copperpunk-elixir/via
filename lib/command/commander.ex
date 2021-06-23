defmodule Command.Commander do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.Sorters, as: Sorters
  require Command.ControlTypes, as: CCT
  require MessageSorter.Sorter

  @commander_loop :commander_loop
  @clear_goals_callback :clear_goals_callback
  def start_link(config) do
    Logger.debug("Start Command.Commander GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    # {default_pilot_control_level, default_goals} = Keyword.fetch!(config, :default_goals)

    commander_loop_interval_ms = Keyword.fetch!(config, :commander_loop_interval_ms)

    state = %{
      # default_pilot_control_level: default_pilot_control_level,
      # default_goals: default_goals,
      goals_store: %{},
      goal_restrictions_store: %{},
      pilot_control_level: nil,
      commander_loop_interval_ms: commander_loop_interval_ms,
      clear_goals_timer: nil
    }

    Comms.Supervisor.start_operator(__MODULE__)
    # ViaUtils.Comms.join_group(__MODULE__, Groups.pilot_control_level_and_goals_sorter(), self())

    MessageSorter.Sorter.register_for_sorter_current_and_stale(
      Sorters.pilot_control_level_and_goals(),
      :value,
      commander_loop_interval_ms
    )

    ViaUtils.Process.start_loop(
      self(),
      commander_loop_interval_ms,
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
    ViaUtils.Process.detach_callback(state.clear_goals_timer)

    clear_goals_timer =
      ViaUtils.Process.attach_callback(
        self(),
        2 * state.commander_loop_interval_ms,
        @clear_goals_callback
      )

    # Logger.debug("Goals sorter rx: #{pilot_control_level}: #{ViaUtils.Format.eftb_map(goals, 3)}")
    {:noreply,
     %{
       state
       | pilot_control_level: pilot_control_level,
         goals_store: goals,
         clear_goals_timer: clear_goals_timer
     }}
  end

  @impl GenServer
  def handle_info(@commander_loop, state) do
    pilot_control_level = state.pilot_control_level
    goals = state.goals_store

    if !is_nil(goals) do
      goals =
        update_goals_to_reflect_goal_restrictions(
          goals,
          state.goal_restrictions_store,
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
  def handle_info(@clear_goals_callback, state) do
    Logger.debug("clear goals: #{inspect(state.goals_store)}")
    {:noreply, %{state | goals_store: %{}}}
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
