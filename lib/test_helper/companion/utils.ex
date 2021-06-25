defmodule TestHelper.Companion.Utils do
  require Logger
  require Command.ActuatorNames, as: Act
  require Ubx.VehicleCmds.BodyrateThrustCmd, as: BodyrateThrustCmd
  require Ubx.VehicleCmds.ActuatorOverrideCmd_1_8, as: ActuatorOverrideCmd_1_8

  @spec display_bodyrate_thrust_cmd(list()) :: :ok
  def display_bodyrate_thrust_cmd(payload) do
    values =
      UbxInterpreter.deconstruct_message(
        BodyrateThrustCmd.bytes(),
        BodyrateThrustCmd.multiplier(),
        BodyrateThrustCmd.keys(),
        payload
      )

    Logger.debug("Companion rx BodyrateThrust: #{ViaUtils.Format.eftb_map(values, 3)}")
  end

  @spec display_actuator_override_cmd_1_8(list()) :: :ok
  def display_actuator_override_cmd_1_8(payload) do
    values =
      UbxInterpreter.deconstruct_message(
        ActuatorOverrideCmd_1_8.bytes(),
        ActuatorOverrideCmd_1_8.multiplier(),
        [
            Act.aileron(),
            Act.elevator(),
            Act.throttle(),
            Act.rudder(),
            Act.flaps(),
            Act.gear(),
            Act.aux1(),
            Act.multiplexor()
          ],
        payload
      )
    Logger.debug("Companion rx ActuatorOverride1-8: #{ViaUtils.Format.eftb_map(values, 3)}")
  end
end
