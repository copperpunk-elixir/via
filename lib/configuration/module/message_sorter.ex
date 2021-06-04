defmodule Configuration.Module.MessageSorter do

  @spec get_config(binary(), binary()) :: list()
  def get_config(model_type, _node_type) do
    [
      sorter_configs: get_sorter_configs(model_type)
    ]
  end


  @spec get_sorter_configs(binary()) :: list()
  def get_sorter_configs(model_type) do
    vehicle_type = Common.Utils.Configuration.get_vehicle_type(model_type)

    vehicle_modules = []#[Control, Navigation]
    generic_modules = []#[Cluster]

    vehicle_sorter_configs =
      Enum.reduce(vehicle_modules, [], fn (module, acc) ->
        module = Module.concat(Configuration.Module, module)
        Enum.concat(acc,apply(module, :get_sorter_configs,[vehicle_type]))
      end)

    module_sorter_configs =
      Enum.reduce(generic_modules, [], fn (module, acc) ->
        module = Module.concat(Configuration.Module, module)
        Enum.concat(acc,apply(module, :get_sorter_configs,[model_type]))
      end)

    vehicle_sorter_configs ++ module_sorter_configs
  end

  @spec get_message_sorter_classification_time_validity_ms(atom(), any()) :: tuple()
  def get_message_sorter_classification_time_validity_ms(sender, sorter) do
    # Logger.debug("sender: #{inspect(sender)}")
    classification_all = %{
      {:hb, :node} => %{
        Cluster.Heartbeat => [1,1]
      },
      :indirect_actuator_cmds => %{
        Control.Controller => [1,1],
        # Navigation.Navigator => [0,2]
      },
      :indirect_override_cmds => %{
        Command.Commander => [1,1],
        # Navigation.PathManager => [0,2]
      },
      {:direct_actuator_cmds, :flaps} => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      {:direct_actuator_cmds, :gear} => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      {:direct_actuator_cmds, :all} => %{
        Command.Commander => [1,1],
      },
      :control_cmds => %{
        Control.Controller => [1,1],
        Navigation.Navigator => [1,2]
      },
      :goals => %{
        Command.Commander => [1,1],
        Navigation.PathManager => [1,2]
      },
      :control_state => %{
        Navigation.Navigator => [1,1]
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
end
