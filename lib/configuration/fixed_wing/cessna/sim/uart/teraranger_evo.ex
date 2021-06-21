defmodule Configuration.FixedWing.Cessna.Sim.Uart.TerarangerEvo do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :TerarangerEvo,
      [
        # expected FT232R
        uart_port: uart_port,
        port_options: [
          speed: 115_200
        ]
      ]
    }
  end
end
