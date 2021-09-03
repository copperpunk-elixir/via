defmodule Configuration.FixedWing.Cessna.Sim.Uart do
  require Logger

  @spec config() :: list()
  def config() do
    peripherals = ["CommandRx_CP2104"]
    config(peripherals)
  end

  @spec config(list()) :: list()
  def config(peripherals) do
    Logger.debug("peripherals: #{inspect(peripherals)}")

    Enum.reduce(peripherals, [], fn peripheral, acc ->
      [module, port] = String.split(peripheral, "_")
      module_config = get_config(module, port)
      module_key = Module.concat([module])
      Keyword.put(acc, module_key, module_config)
    end)
  end

  @spec get_config(binary(), binary()) :: tuple()
  def get_config(module, port) do
    # Logger.debug("port: #{port}")
    uart_port =
      case port do
        "0" -> "ttyAMA0"
        "3" -> "ttyAMA1"
        "4" -> "ttyAMA2"
        "5" -> "ttyAMA3"
        _usb -> port
      end

    config_module = Module.concat(__MODULE__, module)
    apply(config_module, :config, [uart_port])
  end
end
