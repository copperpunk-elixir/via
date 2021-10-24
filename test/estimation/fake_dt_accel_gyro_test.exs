defmodule Estimation.FakeDtAccelGyroTest do
  use ExUnit.Case
  require Logger
  require ViaUtils.Ubx.ClassDefs
  require ViaUtils.Ubx.AccelGyro.DtAccelGyro

  test "Open Serial Port" do
    msg_class = ViaUtils.Ubx.ClassDefs.accel_gyro()
    msg_id = ViaUtils.Ubx.AccelGyro.DtAccelGyro.id()
    byte_types = ViaUtils.Ubx.AccelGyro.DtAccelGyro.bytes()
    multipliers = ViaUtils.Ubx.AccelGyro.DtAccelGyro.multipliers()
    keys = ViaUtils.Ubx.AccelGyro.DtAccelGyro.keys()

    accel_gyro_values = [5000, 1, 2, 3, 4, 5, 6]

    msg = UbxInterpreter.construct_message(msg_class, msg_id, byte_types, accel_gyro_values)

    ubx = UbxInterpreter.new()
    {_ubx, rx_payload} = UbxInterpreter.check_for_new_message(ubx, :binary.bin_to_list(msg))

    rx_values = UbxInterpreter.deconstruct_message(byte_types, multipliers, keys, rx_payload)

    Enum.each(Enum.with_index(keys), fn {key, index} ->
      assert_in_delta(
        rx_values[key],
        Enum.at(accel_gyro_values, index) * Enum.at(multipliers, index),
        0.001
      )
    end)
  end
end
