defmodule Navigation.Navigator do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ControlTypes, as: SCT
  require Configuration.LoopIntervals, as: LoopIntervals
  require Comms.MessageHeaders, as: MessageHeaders
  alias ViaUtils.Watchdog

  @publish_goals_loop :publish_goals_loop
  @attitude :attitude
  @position_velocity :position_velocity
  @clear_values_map_callback :clear_values_map_callback

  def start_link(config) do
    Logger.debug("Start Navigation.Navigation GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    state = %{
      mission: nil,
      route: nil,
      position_rrm: %{},
      velocity_mps: %{},
      attitude_rad: %{},
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
      path_follower_params: Keyword.fetch!(config, :path_follower_params),
      goals_sorter_classification_and_time_validity_ms:
        Keyword.fetch!(config, :goals_sorter_classification_and_time_validity_ms)
    }

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.load_mission(), self())

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.navigator_goals_publish_ms(),
      @publish_goals_loop
    )

    Logger.warn("Nav PID: #{inspect(self())}")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude(), attitude_rad}, state) do
    {:noreply,
     %{
       state
       | attitude_rad: attitude_rad,
         attitude_watchdog: Watchdog.reset(state.attitude_watchdog)
     }}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_position_velocity(), position_rrm, velocity_mps}, state) do
    {:noreply,
     %{
       state
       | position_rrm: position_rrm,
         velocity_mps: velocity_mps,
         position_velocity_watchdog: Watchdog.reset(state.position_velocity_watchdog)
     }}
  end

  @impl GenServer
  def handle_cast({Groups.load_mission(), mission}, state) do
    Logger.debug("Nav load mission: #{mission.name}")
    route = ViaNavigation.calculate_route(mission, state.path_follower_params)
    {:noreply, %{state | mission: mission, route: route}}
  end

  @impl GenServer
  def handle_info(@publish_goals_loop, state) do
    %{
      position_rrm: position_rrm,
      velocity_mps: velocity_mps,
      mission: mission,
      route: route,
      goals_sorter_classification_and_time_validity_ms: class_and_time
    } = state

    {classification, time_validity_ms} = class_and_time

    route =
      if !is_nil(mission) and !Enum.empty?(position_rrm) and !Enum.empty?(velocity_mps) do
        {route, goals} =
          ViaNavigation.update_goals(
            route,
            position_rrm,
            velocity_mps
          )

        unless Enum.empty?(goals) do
          # goals = %{current_pcl: pcl_goals, any_pcl: %{}}

          ViaUtils.Comms.send_global_msg_to_group(
            __MODULE__,
            {MessageHeaders.global_group_to_sorter(), classification, time_validity_ms,
             {SCT.pilot_control_level_3(), goals}},
            Groups.sorter_pilot_control_level_and_goals(),
            self()
          )

          # Logger.debug("Goals: #{inspect(goals)}")
        end

        route
      else
        route
      end

    {:noreply, %{state | route: route}}
  end

  @impl GenServer
  def handle_info({@clear_values_map_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, %{})}
  end
end
