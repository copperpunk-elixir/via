defmodule Ubx.VehicleCmds.AttitudeThrustCmdAttitudeVal do
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.vehicle_cmds()
  defmacro id, do: 0x00
  defmacro cmd_bytes, do: [-2, -2, 2, 2, -2, -2, -2]
  defmacro multipliers, do: [0.01, 0.01, 0.01, 0.0001, 0.01, 0.01, 0.01]
  defmacro keys, do: [:roll_cmd_deg, :pitch_cmd_deg, :yaw_cmd_deg, :thrust_cmd_scaled, :roll_deg, :pitch_deg, :yaw_deg]

end
