defmodule Estimation.Ekf.SevenState.UpdateWithGpsTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects Logger statements from Estimator
    estimator_config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(estimator_config)

    gps_config = full_config[:Uart][:Gps]
    Logger.debug("gps config: #{inspect(gps_config)}")
    Uart.Gps.start_link(gps_config)
    Process.sleep(2000)
  end
end
