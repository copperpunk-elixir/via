defmodule Estimation.Imu.MahonyImuTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects Logger statements from Estimator
    config = full_config[:Uart][:Companion]
    Uart.Companion.start_link(config)
    Process.sleep(200)

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(2000)
  end
end
