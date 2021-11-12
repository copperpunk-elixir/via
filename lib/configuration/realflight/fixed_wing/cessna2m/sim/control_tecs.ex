defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.ControlTecs do
  require ViaUtils.Shared.ControlTypes, as: CCT
  require ViaUtils.Shared.GoalNames, as: SGN

  @spec config() :: list()
  def config() do
    [
      Controller: [
        agl_ceiling_m: 150,
        default_pilot_control_level: CCT.pilot_control_level_2(),
        default_commands: %{
          SGN.current_pcl() => %{
            SGN.roll_rad() => 0.26,
            SGN.pitch_rad() => 0.03,
            SGN.deltayaw_rad() => 0,
            SGN.thrust_scaled() => 0.0
          },
          SGN.any_pcl() => %{
            SGN.flaps_scaled() => 0.0,
            SGN.gear_scaled() => 1.0
          }
        },
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
                feed_forward_speed_max_mps: 20.0,
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
                min_airspeed_for_climb_mps: 8,
                output_min: -0.78,
                output_max: 0.52,
                output_neutral: 0.0
              ],
              roll_course: [
                kp: 0.3,
                ki: 0.1,
                kd: 0.1,
                time_constant_s: 2,
                output_min: -0.78,
                output_max: 0.78,
                output_neutral: 0.0,
                integrator_range: 0.052,
                integrator_airspeed_min_mps: 5.0
              ]
            ]
          ],
          CCT.pilot_control_level_2() => [
            module: ViaControllers.FixedWing.RollPitchDeltayawThrust,
            controller_config: [
              roll: [
                output_min: -6.0,
                output_neutral: 0,
                output_max: 6.0,
                multiplier: 10.0,
                command_rate_max: 1.0,
                initial_command: 0
              ],
              pitch: [
                output_min: -3.0,
                output_neutral: 0,
                output_max: 3.0,
                multiplier: 10.0,
                command_rate_max: 1.0,
                initial_command: 0
              ],
              deltayaw: [
                output_min: -3.0,
                output_neutral: 0,
                output_max: 3.0,
                multiplier: 5.0,
                command_rate_max: 1.5,
                initial_command: 0
              ],
              thrust: [
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
