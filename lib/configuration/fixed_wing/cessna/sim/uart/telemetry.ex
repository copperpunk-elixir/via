defmodule Configuration.FixedWing.Cessna.Sim.Uart.Telemetry do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :CommandRx,
      [
        # SiK or Xbee: FT231X
        uart_port: uart_port,
        port_options: [speed: 57_600],
        fast_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
        medium_loop_interval_ms: Configuration.Generic.loop_interval_ms(:medium),
        slow_loop_interval_ms: Configuration.Generic.loop_interval_ms(:slow)
      ]
    }
  end
end
