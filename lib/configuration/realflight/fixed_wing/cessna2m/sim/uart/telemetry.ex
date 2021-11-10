defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Telemetry do
  alias ViaTelemetry.Ubx.Custom, as: UbxMsg

  def config() do
    [
      telemetry_msgs: [
        UbxMsg.VehicleState.AttitudeAndRates,
        UbxMsg.VehicleState.PositionVelocity,
        # UbxMsg.VehicleCmds.AttitudeThrottleCmd
      ]
    ]
  end
end
