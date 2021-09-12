defmodule Configuration.FixedWing.RfCessna2m.Sim.Uart.CommandRx do
  require Logger
  @spec config(binary()) :: list()
  def config(uart_port) do
    [
      # usually CP2104
      uart_port: uart_port,
      rx_module_config: %{
        FrskyParser => [speed: 100_000, stop_bits: 2, parity: :even],
        DsmParser => [speed: 115_200, stop_bits: 1, parity: :even]
      }
    ]
  end
end
