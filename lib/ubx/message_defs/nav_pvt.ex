defmodule Ubx.MessageDefs.NavPvt do
  defmacro class_id, do: {0x01, 0x07}

  defmacro bytes,
    do: [4, 2, 1, 1, 1, 1, 1, 1, 4, -4, 1, 1, 1, 1, -4, -4, -4, -4, 4, 4, -4, -4, -4]

  defmacro multipliers,
    do: [
      1.0e-3,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1.0e-7,
      1.0e-7,
      1.0e-3,
      1.0e-3,
      1.0e-3,
      1.0e-3,
      1.0e-3,
      1.0e-3,
      1.0e-3,
      1.0e-3
    ]

  defmacro keys,
    do: [
      :itow_s,
      :year,
      :month,
      :day,
      :hour,
      :min,
      :sec,
      :valid,
      :t_acc_ns,
      :nano_ns,
      :fix_type,
      :flags,
      :flags2,
      :num_sv,
      :latitude_deg,
      :longitude_deg,
      :height_m,
      :h_msl_m,
      :h_acc_m,
      :v_acc_m,
      :v_north_mps,
      :v_east_mps,
      :v_down_mps
    ]
end
