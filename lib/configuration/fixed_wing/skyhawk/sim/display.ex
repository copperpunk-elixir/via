defmodule Configuration.FixedWing.Skyhawk.Sim.Display do
  alias ViaTelemetry.Ubx.VehicleCmds, as: VehicleCmds
  alias ViaTelemetry.Ubx.VehicleState, as: VehicleState

  @spec config() :: list()
  def config() do
    [
      Operator: [
        default_messages: %{
          VehicleCmds.AttitudeThrustCmd => 5,
          VehicleCmds.BodyrateThrottleCmd => 5,
          VehicleCmds.SpeedCourseAltitudeSideslipCmd => 5,
          VehicleCmds.SpeedCourserateAltrateSideslipCmd => 5,
          VehicleState.AttitudeAttrateVal => 5,
          VehicleState.PositionVelocityVal => 5
        }
      ],
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: false
    ]
  end
end
