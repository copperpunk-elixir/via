defmodule Configuration.FixedWing.Cessna.Sim.MessageSorter do
  require Command.ControlTypes, as: CCT
  require Comms.Sorters, as: Sorters
  require Comms.Groups, as: Groups
  require MessageSorter.Sorter, as: MSS
  require Comms.MessageHeaders

  @spec config() :: list()
  def config() do
    [
      sorter_configs: sorter_configs()
    ]
  end

  @spec sorter_configs() :: list()
  def sorter_configs() do
    sorter_modules = [Command]

    Enum.reduce(sorter_modules, [], fn module, acc ->
      acc ++ message_sorters_for_module(module)
    end)
  end

  @spec message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def message_sorter_classification_time_validity_ms(sender, sorter) do
    # Logger.debug("sender: #{inspect(sender)}")
    classification_all = %{
      Sorters.heartbeat_node() => %{
        Cluster.Heartbeat => [1, 1]
      },
      Sorters.pilot_control_level_and_goals() => %{
        Command.RemotePilot => [1, 1],
        Navigation.Navigator => [1, 2]
      }
    }

    time_validity =
      case sorter do
        Sorters.heartbeat_node -> 500
        Sorters.pilot_control_level_and_goals -> 300
        _other -> 0
      end

    classification =
      Map.get(classification_all, sorter, %{})
      |> Map.get(sender, nil)

    # time_validity = Map.get(time_validity_all, sorter, 0)
    # Logger.debug("class/time: #{inspect(classification)}/#{time_validity}")
    {classification, time_validity}
  end

  @spec message_sorters_for_module(atom()) :: list()
  def message_sorters_for_module(module) do
    case module do
      Command ->
        [
          [
            name: Sorters.pilot_control_level_and_goals(),
            default_message_behavior: MSS.status_default(),
            default_value: {
              CCT.pilot_control_level_2(),
              %{
                roll_rad: 0.26,
                pitch_rad: 0.03,
                deltayaw_rad: 0,
                throttle_scaled: 0.0,
                flaps_scaled: -1.0,
                gear_scaled: 1.0
              }
            },
            value_type: :tuple,
            publish_value_interval_ms: Configuration.Generic.loop_interval_ms(:medium),
            global_sorter_group: Groups.pilot_control_level_and_goals_sorter()
          ]
        ]
    end
  end
end
