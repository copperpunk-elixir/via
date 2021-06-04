defmodule Estimation.FakeDtAccelGyroTest do
  use ExUnit.Case
  require Logger
  require Ubx.MessageDefs

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Open Serial Port" do
    accel_gyro_values = [5000, 1, 2, 3, 4, 5, 6]
    {msg_class, msg_id} = Ubx.MessageDefs.dt_accel_gyro_val_class_id()
    byte_types = Ubx.MessageDefs.dt_accel_gyro_val_bytes()
    msg = UbxInterpreter.construct_message(msg_class, msg_id, byte_types, accel_gyro_values)

    ubx = UbxInterpreter.new()
    {_ubx, rx_payload} = UbxInterpreter.check_for_new_message(ubx, :binary.bin_to_list(msg))

    rx_values =
      UbxInterpreter.deconstruct_message(Ubx.MessageDefs.dt_accel_gyro_val_bytes(), rx_payload)

    assert rx_values == accel_gyro_values
  end
end
