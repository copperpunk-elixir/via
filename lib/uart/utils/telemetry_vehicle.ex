defmodule Uart.Utils.TelemetryVehicle do
  require Logger
  @spec config(binary()) :: list()
  def config(uart_port) do
    [
      uart_port: uart_port,
      port_options: [speed: 38_400]
    ]
  end
end
