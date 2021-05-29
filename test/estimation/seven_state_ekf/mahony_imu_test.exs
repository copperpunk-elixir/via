defmodule Estimation.SevenStateEkf.MahonyImuTest do
  use ExUnit.Case
  require Logger

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Open Serial Port" do
    # Expects Logger statements from Estimator
    config = Configuration.Module.Peripherals.Uart.get_companion_config("usb", "Pico")
    Peripherals.Uart.Companion.Operator.start_link(config)
    Process.sleep(200)
    config = Configuration.Module.Estimation.get_config("","")[:estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(30000)

  end
end
