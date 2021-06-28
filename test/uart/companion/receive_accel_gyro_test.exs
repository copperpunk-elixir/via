defmodule Peripherals.Uart.Companion.ReceiveAccelGyroTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects Logger statements from Companion operator process_data_fn
    config = full_config[:Uart][:Companion] |> Keyword.put(:uart_port, "USB Serial")
    Uart.Companion.start_link(config)
    Process.sleep(200_000)
  end
end
