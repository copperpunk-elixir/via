defmodule Configuration.FixedWing.Cessna.Hil.Uart.DsmRx do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :CommandRx,
      [
        # usually CP2104
        uart_port: uart_port,
        rx_module: DsmParser,
        port_options: [
          speed: 115_200
        ]
      ]
    }
  end
end
