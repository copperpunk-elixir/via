defmodule Ubx.VehicleCmds.BodyrateThrustCmd do
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.vehicle_cmds()
  defmacro id, do: 0x01
  defmacro bytes, do: [-2, -2, -2, 2]
  defmacro multiplier, do: [1.0e-3, 1.0e-3, 1.0e-3, 1.0e-4]
  defmacro keys, do: [:rollrate_rps, :pitchrate_rps, :yawrate_rps, :thrust_scaled]
end
