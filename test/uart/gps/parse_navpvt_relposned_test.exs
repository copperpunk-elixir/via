defmodule Uart.Gps.ParseNavpvtRelposnedTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects comments from Gps operator
    config = full_config[:Uart][:Gps]
    Uart.Gps.start_link(config)

    Process.sleep(2000)
  end
end
