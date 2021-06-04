defmodule Configuration.Module.Peripherals.Gpio do
  require Logger

  @spec get_config(atom(), atom()) :: list()
  def get_config(_model_type, node_type) do
    [node_type, _node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    peripherals = Common.Utils.Configuration.get_gpio_peripherals(node_type)
    Logger.debug("gpio per: #{inspect(peripherals)}")
    Enum.reduce(peripherals, [], fn (module, acc) ->
      {module_key, module_config} =
        case module do
          "LogPowerButton" -> {Logging, get_log_power_button_config()}
        end
      Keyword.put(acc, module_key, module_config)
    end)
  end

  @spec get_log_power_button_config() :: list()
  def get_log_power_button_config do
    [
      pin_number: 27,
      pin_direction: :input,
      pull_mode: :pullup,
      time_threshold_cycle_mount_ms: 250,
      time_threshold_power_off_ms: 3000
    ]
  end
end
