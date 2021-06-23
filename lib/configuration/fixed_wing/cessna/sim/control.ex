defmodule Configuration.FixedWing.Cessna.Sim.Control do
  require Command.ControlTypes, as: CCT

  @spec config() :: list()
  def config() do
    [
      Controller: [
        default_pilot_control_level: CCT.pilot_control_level_2(),
        default_goals: %{
          CCT.pilot_control_level_2() =>
          %{
          roll_rad: 0.26,
          pitch_rad: 0.03,
          deltayaw_rad: 0,
          throttle_scaled: 0.0,
          flaps_scaled: 0.0,
          gear_scaled: 1.0
        }},
        controller_loop_interval_ms: Configuration.Generic.loop_interval_ms(:medium),
        controllers: %{
          CCT.pilot_control_level_3() => [
            module: ViaControllers.FixedWing.SpeedCourseAltitudeSideslip,
            controller_config: [
              tecs_energy: [
                ki: 0.25,
                kd: 0,
                altitude_kp: 1.0,
                energy_rate_scalar: 0.004,
                integrator_range: 100,
                feed_forward_speed_max_mps: 60.0,
                output_min: 0.0,
                output_max: 1.0,
                output_neutral: 0.0
              ],
              tecs_balance: [
                ki: 0.1,
                kd: 0.0,
                altitude_kp: 0.75,
                balance_rate_scalar: 0.5,
                time_constant: 2.0,
                integrator_range: 0.4,
                integrator_factor: 5.0,
                min_airspeed_for_climb_mps: 10,
                output_min: -0.78,
                output_max: 0.52,
                output_neutral: 0.0
              ],
              roll_course: [
                kp: 0.25,
                ki: 0.0,
                integrator_range: 0.052,
                integrator_airspeed_min: 5.0,
                output_min: -0.78,
                output_max: 0.78,
                output_neutral: 0.0
              ]
            ]
          ],
          CCT.pilot_control_level_2() => [
            module: ViaControllers.FixedWing.RollPitchDeltayawThrottle,
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
              deltayaw: [
                output_min: -3.0,
                output_neutral: 0,
                output_max: 3.0,
                multiplier: 2.0,
                command_rate_max: 1.5,
                initial_command: 0
              ],
              throttle: [
                output_min: 0.0,
                output_neutral: 0.0,
                output_max: 1.0,
                multiplier: 1.0,
                command_rate_max: 0.5,
                initial_command: 0.0
              ]
            ]
          ]
        }
      ]
    ]
  end
end
