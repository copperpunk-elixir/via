defmodule Uart.Companion.UartLoopbackTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects Logger statements from Companion operator process_data_fn
   # Expects comments from Gps operator
    # uart_rx_config = [name: "Rx", uart_port: "Pico", port_options: [speed: 115200]]
    uart_debug_config = [name: "Pico", uart_port: "Pico", port_options: [speed: 115200]]
    Uart.Debug.start_link(uart_debug_config)

    uart_tx_config = [name: "Tx", uart_port: "USB Serial", port_options: [speed: 115200]]

    # TestHelper.Uart.GenServer.start_link(uart_rx_config)
    TestHelper.Uart.GenServer.start_link(uart_tx_config)
    Enum.each(1..100, fn x ->
      TestHelper.Uart.GenServer.send_data("Tx", [x])
      data = TestHelper.Uart.GenServer.get_data("Tx")
      Logger.debug("data: #{inspect(data)}")
      Process.sleep(100)
    end)
      Process.sleep(200_000)
      end
end
