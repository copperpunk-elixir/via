defmodule Uart.Utils.Companion do
  require Logger
  @spec config(binary()) :: list()
  def config(uart_port) do
    [
      uart_port: uart_port,
      port_options: [speed: 115_200]
    ]
  end
end
