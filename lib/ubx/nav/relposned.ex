defmodule Ubx.Nav.Relposned do
  require Ubx.ClassDefs
  defmacro class, do: Ubx.ClassDefs.nav()
  defmacro id, do: 0x3C

  defmacro bytes,
    do: [1, 1, 2, 4, -4, -4, -4, -4, -4, 4, -1, -1, -1, -1, 4, 4, 4, 4, 4, 4, 4]

  defmacro multipliers,
    do: [0, 0, 0, 1.0e-3, 0, 0, 0, 1.0e-2, 1.0e-5, 0, 0, 0, 0, 1.0e-4, 0, 0, 0, 0, 0, 0, 1]

  defmacro keys,
    do: [
      nil,
      nil,
      nil,
      :itow_s,
      nil,
      nil,
      nil,
      :rel_pos_length_m,
      :rel_pos_heading_deg,
      nil,
      nil,
      nil,
      nil,
      :rel_pos_hp_length_m,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      :flags
    ]
end
