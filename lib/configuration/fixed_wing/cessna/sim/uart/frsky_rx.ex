defmodule Configuration.FixedWing.Cessna.Sim.Uart.FrskyRx do
  require Logger
  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :CommandRx,
      [
        # usually CP2104
        uart_port: uart_port,
        rx_module: FrskyParser,
        port_options: [
          speed: 100_000,
          stop_bits: 2,
          parity: :even
        ]
      ]
    }
  end
end
