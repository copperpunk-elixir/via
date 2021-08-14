defmodule Simulation.Xplane.GetEstimationFromXplaneTest do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU
  alias TestHelper.Estimation.GenServer, as: TEG

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Get Estimation From Xplane Test", full_config do
    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = full_config[:Simulation]
    Simulation.Supervisor.start_link(config)

    Process.sleep(200000)
  end
end
