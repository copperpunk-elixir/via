defmodule Configuration.ModifiedConfigTest do
  use ExUnit.Case
  require Logger

  setup do
    # Via.Application.prepare_environment()
    {:ok, []}
  end

  test "empty new config" do
    config_module = Configuration.FixedWing.Skyhawk.Node1.Config
    nav_module = Module.split(config_module) |> List.replace_at(-1, Navigation) |> Module.concat()
    default_nav_config = Configuration.Utils.get_default_config(nav_module)
    single_config = Configuration.Utils.get_merged_config(nav_module)
    Logger.debug("Nav config: #{inspect(single_config)}")
    assert single_config == default_nav_config
    Process.sleep(100)
  end

  test "missing new config" do
    config_module = Configuration.FixedWing.Skyhawk.Node1.Config
    est_module = Module.split(config_module) |> List.replace_at(-1, Estimation) |> Module.concat()
    default_est_config = Configuration.Utils.get_default_config(est_module)
    single_config = Configuration.Utils.get_merged_config(est_module)
    Logger.debug("Est config: #{inspect(single_config)}")
    assert single_config == default_est_config
    Process.sleep(100)

  end

  test "All modules for vehicle" do
    config = Configuration.Utils.config("FixedWing", "Skyhawk", "Node1", [:Uart])
    Logger.debug("config: #{inspect(config)}")
    assert get_in(config, [:Simulation, :simulation, :receive, :publish_airspeed_interval_ms]) == 200
    Process.sleep(100)
  end
end
