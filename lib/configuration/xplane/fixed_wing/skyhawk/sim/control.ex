defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Control do
  require ViaUtils.Shared.ControlTypes, as: CCT

  @spec config() :: list()
  def config() do
    [
      Controller: [
        agl_ceiling_m: 150,
        default_pilot_control_level: CCT.pilot_control_level_2(),
        default_commands: %{
          current_pcl: %{
            roll_rad: 0.26,
            pitch_rad: 0.03,
            deltayaw_rad: 0,
            thrust_scaled: 0.0
          },
          any_pcl: %{
            flaps_scaled: 0.0,
            gear_scaled: 1.0
          }
        },
        controllers: %{
          CCT.pilot_control_level_3() => [
            module: ViaControllers.FixedWing.ScasStAp,
            controller_config: [
              min_airspeed_for_climb_mps: 25,
              speed_thrust: [
                kp: 0.2,
                ki: 0.01,
                kd: 0,
                output_min: 0.0,
                output_neutral: 0.0,
                output_max: 1.0,
                feed_forward_speed_max_mps: 65,
                integrator_range: 5,
                integrator_airspeed_min_mps: 5.0
              ],
              altitude_pitch: [
                kp: 0.025,
                ki: 0.01,
                kd: 0.0,
                output_min: -0.78,
                output_neutral: 0,
                output_max: 0.52,
                integrator_range: 0.5,
                integrator_airspeed_min_mps: 5.0
              ],
              roll_course: [
                kp: 0.25,
                ki: 0.0,
                kd: 0,
                time_constant_s: 4,
                integrator_range: 0.052,
                integrator_airspeed_min_mps: 5.0,
                output_min: -0.78,
                output_max: 0.78,
                output_neutral: 0.0
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
                multiplier: 5.0,
                command_rate_max: 3.0,
                initial_command: 0
              ],
              pitch: [
                output_min: -3.0,
                output_neutral: 0,
                output_max: 3.0,
                multiplier: 5.0,
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
                output_min: -1.0,
                output_neutral: -1.0,
                output_max: 1.0,
                multiplier: 2.0,
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
