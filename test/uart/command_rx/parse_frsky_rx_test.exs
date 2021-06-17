
defmodule Uart.CommandRx.ParseFrskyRxTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
config = Configuration.FixedWing.Cessna.Sim.Uart.get_frsky_rx_config("CP2104")
    Uart.CommandRx.start_link(config)

    Process.sleep(200000)
  end
end
