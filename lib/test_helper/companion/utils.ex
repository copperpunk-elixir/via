defmodule TestHelper.Companion.Utils do
  require Logger
  require ViaUtils.Ubx.VehicleCmds.BodyrateThrustCmd, as: BodyrateThrustCmd

  @spec display_bodyrate_thrust_cmd(list()) :: :ok
  def display_bodyrate_thrust_cmd(payload) do
    values =
      UbxInterpreter.deconstruct_message_to_map(
        BodyrateThrustCmd.bytes(),
        BodyrateThrustCmd.multiplier(),
        BodyrateThrustCmd.keys(),
        payload
      )

    Logger.debug("Companion rx BodyrateThrust: #{ViaUtils.Format.eftb_map(values, 3)}")
  end

end
