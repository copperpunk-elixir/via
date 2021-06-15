defmodule Ubx.MessageDefs do

  defmacro attitude_thrust_cmd_class_id, do: {0x12, 0x00}
  defmacro attitude_thrust_cmd_bytes, do: [-2, -2, 2, 2, -2, -2, -2]
  defmacro bodyrate_thrust_cmd_class_id, do: {0x12, 0x01}
  defmacro bodyrate_thrust_cmd_bytes, do: [-2, -2, -2, 2]
end
