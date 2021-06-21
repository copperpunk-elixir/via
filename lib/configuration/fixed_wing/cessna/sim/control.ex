defmodule Configuration.FixedWing.Cessna.Sim.Control do
  require Command.ControlTypes, as: CCT
  @spec config() :: list()
  def config() do
    [
      Controller: [
        default_goals: %{
          CCT.pilot_control_level_roll_pitch_yawrate_throttle() => %{
            roll_rad: 0.26,
            pitch_rad: 0.03,
            yawrate_rad: 0,
            throttle_scaled: 0,
            flaps_scaled: 0,
            gear_scaled: 1.0
          }
        },
        controller_loop_interval_ms: Configuration.Generic.loop_interval_ms(:medium)
      ]
    ]
  end
end
