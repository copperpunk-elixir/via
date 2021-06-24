defmodule Ubx.AccelGyro.DtAccelGyro do
  require ViaUtils.Constants, as: VC
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.accel_gyro()
  defmacro id, do: 0x00
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

  defmacro keys, do: [:dt_s, :ax_mpss, :ay_mpss, :az_mpss, :gx_rps, :gy_rps, :gz_rps]
end
