defmodule Configuration.FixedWing.Cessna.Hil.Uart do
  require Logger

  @spec config() :: list()
  def config() do
    peripherals = ["Gps_u-blox", "Companion_Pico", "FrskyRx_CP2104"]
    config(peripherals)
  end

  @spec config(list()) :: list()
  def config(peripherals) do
    # Logger.warn("uart node type: #{node_type}")
    # peripherals = Configuration.Utils.get_uart_peripherals("Hil")
    Logger.debug("peripherals: #{inspect(peripherals)}")

    Enum.reduce(peripherals, [], fn peripheral, acc ->
      # peripheral_string = Atom.to_string(name)
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

    # # Logger.debug("device/meta: #{device}/#{metadata}")
    config_module = Module.concat(__MODULE__, device)
    apply(config_module, :module_key_and_config, [uart_port])
  end
end
