
defmodule Simulation.Realflight.RcPassthroughTest do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "RC Passthrough Test", full_config do
    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = full_config[:Simulation]
    Simulation.Supervisor.start_link(config)

    Process.sleep(200000)
  end
end
