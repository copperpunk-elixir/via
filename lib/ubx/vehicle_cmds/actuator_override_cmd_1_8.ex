defmodule Ubx.VehicleCmds.ActuatorOverrideCmd_1_8 do
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.vehicle_cmds()
  defmacro id, do: 0x10
  defmacro bytes, do: [-2, -2, -2, -2, -2, -2, -2, -2, 1]
  defmacro multiplier, do: [1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4, 1]
  # Keys must be defined by the sender, as they will determine the channel order
end
