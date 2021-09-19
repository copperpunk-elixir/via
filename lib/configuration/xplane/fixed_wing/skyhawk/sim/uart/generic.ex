defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Uart.Generic do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    [uart_port, device_capability] =
      case String.split(uart_port, "-") do
        [port] -> [port, ""]
        [port, capability] -> [port, capability]
        _other -> raise "Device name improper format"
      end

    sorter_classification =
      Configuration.Generic.generic_peripheral_classification(device_capability)

    {
      :Generic,
      [
        uart_port: uart_port,
        port_options: [speed: 115_200],
        sorter_classification: sorter_classification
      ]
    }
  end
end
