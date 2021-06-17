defmodule Command.CommanderReceivingRxTest do
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
    config = Configuration.FixedWing.Cessna.Sim.Command.config()
    Command.Commander.start_link(config[:Commander])

    Process.sleep(200_000)
  end
end
