defmodule Configuration.FixedWing.Cessna.Hil.Uart.Gps do
  require Logger

  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :Gps,
      [
        # usually u-blox
        uart_port: uart_port,
        port_options: [speed: 115_200],
        expected_antenna_distance_mm: 18225,
        antenna_distance_error_threshold_mm: 200
      ]
    }
  end
end
