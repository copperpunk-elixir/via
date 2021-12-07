defmodule Configuration.FixedWing.Skyhawk.Node1.Simulation do
  @spec config() :: list()
  def config() do
    xplane()
  end

  def xplane() do
    [
      simulation: [
        module: XplaneIntegration,
        receive: [
          publish_gps_position_velocity_interval_ms: 100,
          publish_gps_relative_heading_interval_ms: 100,
          publish_airspeed_interval_ms: 100,
          publish_downward_range_distance_interval_ms: 100
        ]
      ]
    ]
  end

  def none() do
    []
  end

  def any() do
    []
  end
end
