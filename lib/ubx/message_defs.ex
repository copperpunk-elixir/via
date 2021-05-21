defmodule Ubx.MessageDefs do

  defmacro accel_gyro_val_class_id, do: {0x11, 0x00}
  defmacro accel_gyro_val_bytes, do: [2, -2, -2, -2, -2, -2, -2]
  defmacro attitude_thrust_cmd_class_id, do: {0x12, 0x00}
  defmacro attitude_thrust_cmd_bytes, do: [-2, -2, 2, 2, -2, -2, -2]
  defmacro bodyrate_thrust_cmd_class_id, do: {0x12, 0x01}
  defmacro bodyrate_thrust_cmd_bytes, do: [-2, -2, -2, 2]

end
