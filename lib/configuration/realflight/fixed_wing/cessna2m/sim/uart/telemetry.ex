defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Telemetry do
  alias ViaTelemetry.Ubx.Custom, as: UbxMsg

  def config() do
    [
      telemetry_msgs: [
        UbxMsg.VehicleState.AttitudeAndRates,
        UbxMsg.VehicleState.PositionVelocity,
        UbxMsg.VehicleCmds.BodyrateThrottleCmd,
        UbxMsg.VehicleCmds.AttitudeThrustCmd,
        UbxMsg.VehicleCmds.SpeedCourseAltitudeSideslipCmd,
        UbxMsg.VehicleCmds.SpeedCourserateAltrateSideslipCmd
      ],
      vehicle_id: Configuration.Utils.get_vehicle_id(__MODULE__)
    ]
  end
end
