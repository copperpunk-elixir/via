defmodule Configuration.FixedWing.Skyhawk.Sim.Control do
  require ViaUtils.Shared.ControlTypes, as: SCT
  require ViaUtils.Shared.GoalNames, as: SGN

  @spec config() :: list()
  def config() do
    [
      Controller: [
        agl_ceiling_m: 150,
        default_pilot_control_level: SCT.pilot_control_level_2(),
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
          SCT.pilot_control_level_3() => [
            module: ViaControllers.FixedWing.ScasStAp,
            controller_config: [
              {SCT.min_airspeed_for_climb_mps(), 25},
              {SCT.speed_thrust_pid(),
               [
                 {SCT.kp(), 0.2},
                 {SCT.ki(), 0.01},
                 {SCT.kd(), 0},
                 {SCT.output_min(), 0.0},
                 {SCT.output_neutral(), 0.0},
                 {SCT.output_max(), 1.0},
                 {SCT.feed_forward_speed_max_mps(), 65},
                 {SCT.integrator_range(), 5},
                 {SCT.integrator_airspeed_min_mps(), 5.0}
               ]},
              {SCT.altitude_pitch_pid(),
               [
                 {SCT.kp(), 0.025},
                 {SCT.ki(), 0.01},
                 {SCT.kd(), 0.0},
                 {SCT.output_min(), -0.78},
                 {SCT.output_neutral(), 0},
                 {SCT.output_max(), 0.52},
                 {SCT.integrator_range(), 0.5},
                 {SCT.integrator_airspeed_min_mps(), 5.0}
               ]},
              {SCT.course_roll_pid(),
               [
                 {SCT.kp(), 0.25},
                 {SCT.ki(), 0.0},
                 {SCT.kd(), 0},
                 {SCT.time_constant_s(), 4},
                 {SCT.integrator_range(), 0.052},
                 {SCT.integrator_airspeed_min_mps(), 5.0},
                 {SCT.output_min(), -0.78},
                 {SCT.output_max(), 0.78},
                 {SCT.output_neutral(), 0.0}
               ]}
            ]
          ],
          SCT.pilot_control_level_2() => [
            module: ViaControllers.FixedWing.RollPitchDeltayawThrust,
            controller_config: [
              {SCT.roll_rollrate_scalar(),
               [
                 {SCT.output_min(), -6.0},
                 {SCT.output_neutral(), 0},
                 {SCT.output_max(), 6.0},
                 {SCT.multiplier(), 5.0},
                 {SCT.command_rate_max(), 3.0},
                 {SCT.initial_command(), 0}
               ]},
              {SCT.pitch_pitchrate_scalar(),
               [
                 {SCT.output_min(), -3.0},
                 {SCT.output_neutral(), 0},
                 {SCT.output_max(), 3.0},
                 {SCT.multiplier(), 5.0},
                 {SCT.command_rate_max(), 1.0},
                 {SCT.initial_command(), 0}
               ]},
              {SCT.deltayaw_yawrate_scalar(),
               [
                 {SCT.output_min(), -3.0},
                 {SCT.output_neutral(), 0},
                 {SCT.output_max(), 3.0},
                 {SCT.multiplier(), 5.0},
                 {SCT.command_rate_max(), 1.5},
                 {SCT.initial_command(), 0}
               ]},
              {SCT.thrust_throttle_scalar(),
               [
                 {SCT.output_min(), -1.0},
                 {SCT.output_neutral(), -1.0},
                 {SCT.output_max(), 1.0},
                 {SCT.multiplier(), 2.0},
                 {SCT.command_rate_max(), 0.5},
                 {SCT.initial_command(), 0.0}
               ]}
            ]
          ]
        }
      ]
    ]
  end
end
