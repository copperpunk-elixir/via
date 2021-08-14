defmodule Configuration.FixedWing.Cessna.Hil.Uart.Telemetry do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :Telemetry,
      [
        # SiK or Xbee: FT231X
        uart_port: uart_port,
        port_options: [speed: 57_600]
      ]
    }
  end
end
