defmodule Peripherals.Estimation.SevenStateEkf.UpdateWithGpsTest do
  use ExUnit.Case
  require Logger

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Open Serial Port" do
    # Expects Logger statements from Estimator
    config = Configuration.Module.Estimation.get_config("", "")[:estimator]
    Estimation.Estimator.start_link(config)

    config = Configuration.Module.Peripherals.Uart.get_gps_config("usb", "u-blox")
    Peripherals.Uart.Gps.Operator.start_link(config)
    Process.sleep(20000)
  end
end
