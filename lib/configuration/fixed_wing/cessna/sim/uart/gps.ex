defmodule Configuration.FixedWing.Cessna.Sim.Uart.Gps do
  require Logger

  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :Gps,
      [
        # usually u-blox
        uart_port: uart_port,
        port_options: [speed: 115_200],
        gps_expected_antenna_distance_mm: 18225,
        gps_antenna_distance_error_threshold_mm: 200
      ]
    }
  end
end
