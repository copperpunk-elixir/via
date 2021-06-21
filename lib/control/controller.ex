defmodule Control.Controller do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.Sorters, as: Sorters
  require Command.ControlTypes, as: CCT
  require MessageSorter.Sorter

  @controller_loop :controller_loop
  @clear_goals_loop :clear_goals_loop
  @clear_remote_pilot_override_loop :clear_remote_pilot_override_loop

  def start_link(config) do
    Logger.debug("Start Control.Controller GenServer")
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
      pilot_control_level: default_pilot_control_level,
      remote_pilot_goals_override: %{},
      remote_pilot_override: false
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.commander_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.remote_pilot_goals_override(), self())

    controller_loop_interval_ms = Keyword.fetch!(config, :controller_loop_interval_ms)

    ViaUtils.Process.start_loop(
      self(),
      controller_loop_interval_ms,
      @controller_loop
    )

    ViaUtils.Process.start_loop(
      self(),
      2 * controller_loop_interval_ms,
      @clear_goals_loop
    )

    ViaUtils.Process.start_loop(
      self(),
      10 * controller_loop_interval_ms,
      @clear_remote_pilot_override_loop
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
    goals_store = Map.put(state.goals_store, pilot_control_level, goals)

    # Logger.debug(
    #   "Controller goals rx: #{pilot_control_level}: #{ViaUtils.Format.eftb_map(goals, 3)}"
    # )

    {:noreply, %{state | pilot_control_level: pilot_control_level, goals_store: goals_store}}
  end

  @impl GenServer
  def handle_cast({Groups.remote_pilot_goals_override(), goals}, state) do
    # Logger.debug("Remote override rx: #{ViaUtils.Format.eftb_map(goals, 3)}")
    {:noreply, %{state | remote_pilot_override: true, remote_pilot_goals_override: goals}}
  end

  @impl GenServer
  def handle_info(@controller_loop, state) do
    if state.remote_pilot_override do
      goals = state.remote_pilot_goals_override
      Logger.warn("ctrl loop override/goals: #{ViaUtils.Format.eftb_map(goals, 3)}")
    else
      pilot_control_level = state.pilot_control_level
      goals = Map.get(state.goals_store, pilot_control_level, %{})

      {pilot_control_level, goals} =
        if Enum.empty?(goals) do
          {state.default_pilot_control_level, state.default_goals}
        else
          {pilot_control_level, goals}
        end

      Logger.debug(
        "ctrl loop. pcl/goals: #{pilot_control_level}/#{ViaUtils.Format.eftb_map(goals, 3)}"
      )
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@clear_goals_loop, state) do
    # Logger.debug("clear goals: #{inspect(state.goals_store)}")
    {:noreply, %{state | goals_store: %{}, pilot_control_level: nil}}
  end

  @impl GenServer
  def handle_info(@clear_remote_pilot_override_loop, state) do
    # Logger.debug("clear goals: #{inspect(state.goals_store)}")
    {:noreply, %{state | remote_pilot_override: false}}
  end
end
