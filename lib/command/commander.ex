defmodule Command.Commander do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.Sorters, as: Sorters

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
      pilot_control_level: Key
    }

    Comms.Supervisor.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, Groups.dt_accel_gyro_val(), self())
    Comms.Operator.join_group(__MODULE__, Groups.gps_itow_position_velocity(), self())
    Comms.Operator.join_group(__MODULE__, Groups.goals_sorter(), self())

    ViaUtils.Process.start_loop(
      self(),
      Keyword.fetch!(config, :commander_loop_interval_ms),
      :commander_loop
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
        {Groups.goals_sorter(), pilot_control_level, classification, time_validity_ms, goals},
        state
      ) do
    Logger.debug("nav rx: #{ViaUtils.Format.eftb_map(goals, 3)}")

    MessageSorter.Sorter.add_message(
      Groups.goals_for_pilot_control_level(pilot_control_level),
      classification,
      time_validity_ms,
      goals
    )

    MessageSorter.Sorter.add_message(
      Groups.pilot_control_level(),
      classification,
      time_validity_ms,
      pilot_control_level
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {Groups.message_sorter_value(), {Sorters.goals(), pilot_control_level}, _classification,
         goals, status},
        state
      ) do
    goals_store =
      if status == :current do
        Map.put(state.goals_store, pilot_control_level, goals)
      else
        Map.drop(state.goals_store, [pilot_control_level])
      end

    {:noreply, %{state | goals_store: goals_store}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.pilot_control_level(), pilot_control_level, _classification, pilot_control_level,
         _status},
        state
      ) do
    {:noreply, %{state | pilot_control_level: pilot_control_level}}
  end

  @impl GenServer
  def handle_info(:commander_loop, state) do
    pilot_control_level = state.pilot_control_level
    goals = Map.get(state.goals_store, pilot_control_level
    goals = if is_nil(goals), do: state.default_goals

    Logger.debug("loop. current pcl/goals: #{pilot_control_level}/#{inspect(goals)}")
    {:noreply, state}
  end
end
