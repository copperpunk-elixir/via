defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Gps do
  def config() do
    [
      expected_gps_antenna_distance_m: 1,
      gps_antenna_distance_error_threshold_mm: 0.01
    ]
  end
end
