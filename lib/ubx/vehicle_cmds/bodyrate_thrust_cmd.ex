defmodule Ubx.VehicleCmds.BodyrateThrustCmd do
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.vehicle_cmds()
  defmacro id, do: 0x01
  defmacro bytes, do: [-2, -2, -2, 2]
  defmacro multiplier, do: [0.1, 0.1, 0.1, 0.1]
  defmacro keys, do: [:roll_rate_cmd_dps, :pitch_rate_cmd_dps, :yaw_rate_cmd_dps, :thrust_cmd_scaled]
end
