defmodule Uart.CommandRx.ProcotolIdTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    Logger.info("mix env: #{Mix.env()}")
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
    config = [
      # usually CP2104
      uart_port: "CP2104",
      rx_module_config: %{
        FrskyParser => [speed: 100_000, stop_bits: 2, parity: :even],
        DsmParser => [speed: 115_200, stop_bits: 1, parity: :even]
      }
    ]

    Uart.CommandRx.start_link(config)

    Process.sleep(200_000)
  end
end
