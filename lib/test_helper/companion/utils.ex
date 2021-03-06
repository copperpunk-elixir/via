defmodule TestHelper.Companion.Utils do
  require Logger
  require ViaTelemetry.Ubx.VehicleCmds.BodyrateThrottleCmd, as: BodyrateThrottleCmd

  @spec display_bodyrate_thrust_cmd(list()) :: :ok
  def display_bodyrate_thrust_cmd(payload) do
    values =
      UbxInterpreter.deconstruct_message_to_map(
        BodyrateThrottleCmd.bytes(),
        BodyrateThrottleCmd.multipliers(),
        BodyrateThrottleCmd.keys(),
        payload
      )

    Logger.debug("Companion rx BodyrateThrottle: #{ViaUtils.Format.eftb_map(values, 3)}")
  end

end
