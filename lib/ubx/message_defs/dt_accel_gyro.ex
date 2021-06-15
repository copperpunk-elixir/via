defmodule Ubx.MessageDefs.DtAccelGyroVal do
  require ViaUtils.Constants, as: VC
  defmacro class_id, do: {0x11, 0x00}
  defmacro bytes, do: [2, -2, -2, -2, -2, -2, -2]

  defmacro multipliers,
    do: [
      1.0e-6,
      VC.gravity() / 8192,
      VC.gravity() / 8192,
      VC.gravity() / 8192,
      VC.deg2rad() / 16.4,
      VC.deg2rad() / 16.4,
      VC.deg2rad() / 16.4
    ]

  defmacro keys, do: [:dt, :ax, :ay, :az, :gx, :gy, :gz]
end
