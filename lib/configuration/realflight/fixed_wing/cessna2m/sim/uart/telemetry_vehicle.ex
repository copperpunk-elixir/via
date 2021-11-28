defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.TelemetryVehicle do
  alias ViaTelemetry.Ubx, as: UbxMsg

  def config() do
    [
      telemetry_msgs: [
        UbxMsg.VehicleState.AttitudeAttrateVal,
        UbxMsg.VehicleState.PositionVelocityVal,
        UbxMsg.VehicleCmds.BodyrateThrottleCmd,
        UbxMsg.VehicleCmds.AttitudeThrustCmd,
        UbxMsg.VehicleCmds.SpeedCourseAltitudeSideslipCmd,
        UbxMsg.VehicleCmds.SpeedCourserateAltrateSideslipCmd
      ],
      vehicle_id: Configuration.Utils.get_vehicle_id(__MODULE__)
    ]
  end
end
