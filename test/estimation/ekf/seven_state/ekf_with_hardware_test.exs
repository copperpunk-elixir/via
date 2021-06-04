defmodule Peripherals.Estimation.Ekf.SevenState.EkfWithHardware do
  use ExUnit.Case
  require Logger

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Open Serial Port" do
    config = Configuration.Module.Estimation.get_config("", "")[:estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = Configuration.Module.Peripherals.Uart.get_companion_config("usb", "Pico")
    Peripherals.Uart.Companion.start_link(config)
    Process.sleep(200)

    config = Configuration.Module.Peripherals.Uart.get_gps_config("usb", "u-blox")
    Peripherals.Uart.Gps.start_link(config)
    Process.sleep(2000)
  end
end
