defmodule Uart.CommandRx.ParseDsmRxTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
    config = Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.config(["DsmRx_CP2104"])
    Uart.CommandRx.start_link(config[:CommandRx])

    Process.sleep(200000)
  end
end
