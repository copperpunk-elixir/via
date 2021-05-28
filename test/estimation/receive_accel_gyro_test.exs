defmodule Estimation.ReceiveAccelGyroTest do
  use ExUnit.Case
  require Logger

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Open Serial Port" do
    Ubx.Utils.Test.start_link([groups: [:dt_accel_gyro_val], destination: self()])
    config = Configuration.Module.Peripherals.Uart.get_companion_config("usb", "USB Serial")
    Peripherals.Uart.Companion.Operator.start_link(config)
    Process.sleep(200)
    Logger.warn("test pid: #{inspect(self())}")
    accel_gyro_values = [5000,1,2,3,4,5,6]
    msg = Ubx.Utils.Test.build_message(:dt_accel_gyro_val, accel_gyro_values)
    Peripherals.Uart.Companion.Operator.send_message(msg)

    rx_values =
    receive do
      {:accel_gyro_val, values} -> values
    after
      500 -> []
    end

    assert rx_values == accel_gyro_values
  end
end
