defmodule Command.RemotePilotReceivingRxTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
    config = Configuration.FixedWing.RfCessna2m.Sim.Uart.get_frsky_rx_config("CP2104")
    Uart.CommandRx.start_link(config)
    config = Configuration.FixedWing.RfCessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])

    Process.sleep(200_000)
  end
end
