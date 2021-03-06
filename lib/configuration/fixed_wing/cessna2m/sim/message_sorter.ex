defmodule Configuration.FixedWing.Cessna2m.Sim.MessageSorter do
  require ViaUtils.Shared.ControlTypes, as: CCT
  require Comms.Sorters, as: Sorters
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.GoalNames, as: SGN
  require MessageSorter.Sorter, as: MSS
  require Comms.MessageHeaders
  require Configuration.LoopIntervals, as: LoopIntervals

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
        Cluster.Heartbeat => {[1, 1], 5 * LoopIntervals.heartbeat_publish_ms()}
      },
      Sorters.pilot_control_level_and_goals() => %{
        Command.RemotePilot => {[1, 1], 5 * LoopIntervals.remote_pilot_goals_publish_ms()},
        Navigation.Navigator => {[1, 2], 5 * LoopIntervals.navigator_goals_publish_ms()}
      }
    }

    Map.get(classification_all, sorter, %{})
    |> Map.get(sender, nil)
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
                SGN.current_pcl() => %{
                  SGN.roll_rad() => 0.26,
                  SGN.pitch_rad() => 0.03,
                  SGN.deltayaw_rad() => 0,
                  SGN.thrust_scaled() => 0.0
                },
                SGN.any_pcl() => %{
                  SGN.flaps_scaled() => 0.0,
                  SGN.gear_scaled() => 1.0
                }
              }
            },
            value_type: :tuple,
            publish_value_interval_ms: LoopIntervals.commands_publish_ms(),
            global_sorter_group: Groups.sorter_pilot_control_level_and_goals()
          ]
        ]
    end
  end
end
