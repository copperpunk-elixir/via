defmodule Configuration.FixedWing.Cessna.Sim.Uart do
  require Logger

  @spec config() :: list()
  def config() do
    peripherals = ["FrskyRx_CP2104"]
    config(peripherals)
  end

  @spec config(list()) :: list()
  def config(peripherals) do
    Logger.debug("peripherals: #{inspect(peripherals)}")

    Enum.reduce(peripherals, [], fn peripheral, acc ->
      [device, port] = String.split(peripheral, "_")
      {module_key, module_config} = get_module_key_and_config(device, port)
      Keyword.put(acc, module_key, module_config)
    end)
  end

  @spec get_module_key_and_config(binary(), binary()) :: tuple()
  def get_module_key_and_config(device, port) do
    # Logger.debug("port: #{port}")
    uart_port =
      case port do
        "0" -> "ttyAMA0"
        "3" -> "ttyAMA1"
        "4" -> "ttyAMA2"
        "5" -> "ttyAMA3"
        _usb -> port
      end

    config_module = Module.concat(__MODULE__, device)
    apply(config_module, :module_key_and_config, [uart_port])
  end
end
