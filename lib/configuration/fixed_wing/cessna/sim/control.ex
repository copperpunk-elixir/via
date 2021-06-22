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
            yawrate_rps: 0,
            throttle_scaled: 0,
            flaps_scaled: 0,
            gear_scaled: 1.0
          }
        },
        controller_loop_interval_ms: Configuration.Generic.loop_interval_ms(:medium),
        roll_pitch_yawrate_throttle_controller: [
          module: ViaControllers.FixedWing.RollPitchYawrateThrottle,
          controller_config: [
            roll: [
              output_min: -6.0,
              output_neutral: 0,
              output_max: 6.0,
              multiplier: 2.0,
              command_rate_max: 1.0,
              initial_command: 0
            ],
            pitch: [
              output_min: -3.0,
              output_neutral: 0,
              output_max: 3.0,
              multiplier: 2.0,
              command_rate_max: 1.0,
              initial_command: 0
            ],
            yawrate: [
              output_min: -3.0,
              output_neutral: 0,
              output_max: 3.0,
              multiplier: 1.0,
              command_rate_max: 1.5,
              initial_command: 0
            ],
            throttle: [
              output_min: 0.0,
              output_neutral: 0.0,
              output_max: 1.0,
              multiplier: 1.0,
              command_rate_max: 0.5,
              initial_command: 0
            ]
          ]
        ]
      ]
    ]
  end
end
