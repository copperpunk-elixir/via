defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Telemetry do
  alias ViaTelemetry.Ubx, as: UbxMsg

  def config() do
    [
      telemetry_msgs: [
        UbxMsg.VehicleState.Attitude,
        UbxMsg.VehicleState.PositionVelocity
      ]
    ]
  end
end
