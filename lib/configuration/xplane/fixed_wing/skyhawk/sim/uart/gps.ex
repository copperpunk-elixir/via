defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Uart.Gps do
  def config() do
    [
      expected_gps_antenna_distance_m: 1,
      gps_antenna_distance_error_threshold_m: 0.010
    ]
  end
end
