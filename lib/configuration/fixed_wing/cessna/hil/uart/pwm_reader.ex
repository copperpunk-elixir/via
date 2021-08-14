defmodule Configuration.FixedWing.Cessna.Hil.Uart.PwmReader do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :PwmReader,
      [
        uart_port: uart_port,
        port_options: [speed: 115_200]
      ]
    }
  end
end
