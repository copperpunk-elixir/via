defmodule Ubx.MessageDefs do
  defmacro nav_pvt_class_id, do: {0x01, 0x07}

  defmacro nav_pvt_bytes,
    do: [4, 2, 1, 1, 1, 1, 1, 1, 4, -4, 1, 1, 1, 1, -4, -4, -4, -4, 4, 4, -4, -4, -4]
  defmacro nav_relposned_class_id, do: {0x01, 0x3C}
  defmacro nav_relposned_bytes, do: [1,1,2,4,-4,-4,-4,-4,-4,4,-1,-1,-1,-1,4,4,4,4,4,4,4]
  defmacro dt_accel_gyro_val_class_id, do: {0x11, 0x00}
  defmacro dt_accel_gyro_val_bytes, do: [2, -2, -2, -2, -2, -2, -2]
  defmacro attitude_thrust_cmd_class_id, do: {0x12, 0x00}
  defmacro attitude_thrust_cmd_bytes, do: [-2, -2, 2, 2, -2, -2, -2]
  defmacro bodyrate_thrust_cmd_class_id, do: {0x12, 0x01}
  defmacro bodyrate_thrust_cmd_bytes, do: [-2, -2, -2, 2]
end
