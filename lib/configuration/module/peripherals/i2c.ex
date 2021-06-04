defmodule Configuration.Module.Peripherals.I2c do
  require Logger
  @spec get_config(atom(), atom()) :: list()
  def get_config(_model_type, node_type) do
    [node_type, _node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    peripherals = Common.Utils.Configuration.get_i2c_peripherals(node_type)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, [], fn (peripheral, acc) ->
      Logger.debug("peripheral: #{inspect(peripheral)}")
      device_and_metadata = String.split(peripheral, "_")
      device = Enum.at(device_and_metadata,0)
      metadata = Enum.at(device_and_metadata,1)
      {module_key, module_config} =
        case device do
          "Ina260" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Ina219" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Sixfab" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "Atto90" ->
            {module, type, channel} = get_battery_module_type_channel(device, metadata)
            {Health.Battery, get_battery_config(module, type, channel)}
          "TerarangerEvo" ->
            {Estimation.TerarangerEvo, get_teraranger_config()}
        end
      acc ++ Keyword.put([], module_key, module_config)
    end)
  end

  @spec get_battery_module_type_channel(binary(), binary()) :: tuple()
  def get_battery_module_type_channel(device, metadata) do
    module = String.to_existing_atom(device)
    [type, channel] = String.split(metadata,"-")
    channel = String.to_integer(channel)
    {module, type, channel}
  end

  @spec get_battery_config(binary(), binary(), integer()) :: list()
  def get_battery_config(module, battery_type, battery_channel) do
    read_battery_interval_ms =
      case battery_type do
        "cluster" -> 1000
        "motor" -> 1000
      end
    [
      module: module,
      battery_type: battery_type,
      battery_channel: battery_channel,
      read_battery_interval_ms: read_battery_interval_ms
    ]
  end

  @spec get_teraranger_config() :: list()
  def get_teraranger_config() do
    [
      read_range_interval_ms: 100
    ]
  end

end
