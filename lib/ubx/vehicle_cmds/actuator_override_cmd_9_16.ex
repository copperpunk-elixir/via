defmodule Ubx.VehicleCmds.ActuatorOverrideCmd_9_16 do
  require Ubx.ClassDefs
  require Command.ActuatorNames, as: Act
  defmacro class, do: Ubx.ClassDefs.vehicle_cmds()
  defmacro id, do: 0x11
  defmacro bytes, do: [-2, -2, -2, -2, -2, -2, -2, -2]
  defmacro multiplier, do: [1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4,1.0e-4]
  defmacro keys, do: [Act.aileron(), Act.elevator(), Act.throttle(), Act.rudder(), Act.flaps(), Act.gear(), Act.aux1()]
end
