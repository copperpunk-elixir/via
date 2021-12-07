defmodule Uart.Utils.TelemetryVehicle do
  require Logger
  @spec config(binary()) :: list()
  def config(uart_port) do
    [
      uart_port: uart_port,
      port_options: [speed: 38_400],
      publish_messages_frequency_max_hz: 50,
      vehicle_id: Configuration.Utils.get_vehicle_id(__MODULE__)
    ]
  end
end
