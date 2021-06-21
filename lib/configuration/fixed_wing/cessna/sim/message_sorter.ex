defmodule Configuration.FixedWing.Cessna.Sim.MessageSorter do
  require Command.ControlTypes, as: CCT
  require Comms.Sorters, as: Sorters
  require MessageSorter.Sorter, as: MSS

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
      {:hb, :node} => %{
        Cluster.Heartbeat => [1, 1]
      },
      :control_cmds => %{
        Control.Controller => [1, 1],
        Navigation.Navigator => [1, 2]
      },
      :goals => %{
        Command.RemotePilot => [1, 1],
        Navigation.PathManager => [1, 2]
      },
      :control_state => %{
        Navigation.Navigator => [1, 1]
      }
    }

    time_validity =
      case sorter do
        {:hb, :node} -> 500
        :indirect_actuator_cmds -> 200
        :indirect_override_cmds -> 200
        {:direct_actuator_cmds, _} -> 200
        :control_cmds -> 300
        :goals -> 300
        :control_state -> 200
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
        goals_sorters =
          Enum.map(
            CCT.pilot_control_level_rollrate_pitchrate_yawrate_throttle()..CCT.pilot_control_level_speed_course_altitude_sideslip(),
            fn pilot_control_level ->
              [
                name: {Sorters.goals(), pilot_control_level},
                default_message_behavior: MSS.status_default(),
                default_value: nil,
                value_type: :map,
                publish_value_interval_ms: Configuration.Generic.loop_interval_ms(:medium)
              ]
            end
          )

        pilot_control_level_sorter = [
          [
            name: Sorters.pilot_control_level(),
            default_message_behavior: MSS.status_default(),
            default_value: CCT.pilot_control_level_roll_pitch_yawrate_throttle(),
            value_type: :number,
            publish_value_interval_ms: Configuration.Generic.loop_interval_ms(:medium)
          ]
        ]

        goals_sorters ++ pilot_control_level_sorter

    end
  end
end
