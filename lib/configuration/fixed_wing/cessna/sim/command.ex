defmodule Configuration.FixedWing.Cessna.Sim.Command do
  require Command.ControlTypes, as: CCT
  @spec config() :: list()
  def config() do
    [
      Commander: [
        num_channels: 12,
        control_level_dependent_channel_number_min_mid_max: %{
          CCT.pilot_control_level_speed_courserate_altituderate_sideslip() => %{
            course_rate_rps: {0, -0.52, 0, 0.52, CCT.input_not_inverted()},
            altitude_rate_mps: {1, -1.0, 0, 2.0, CCT.input_inverted()},
            speed_mps: {2, 0, 15.0, 30.0, CCT.input_not_inverted()},
            sideslip_rad: {3, -0.26, 0, 0.26, CCT.input_not_inverted()}
          },
          CCT.pilot_control_level_roll_pitch_yawrate_throttle() => %{
            roll_rad: {0, -1.05, 0, 1.05, CCT.input_not_inverted()},
            pitch_rad: {1, -0.52, 0, 0.52, CCT.input_inverted()},
            throttle_scaled: {2, 0, 0.5, 1.0, CCT.input_not_inverted()},
            yawrate_rps: {3, -3.14, 0, 3.14, CCT.input_not_inverted()}
          },
          CCT.pilot_control_level_rollrate_pitchrate_yawrate_throttle() => %{
            rollrate_rps: {0, -6.28, 0, 6.28, CCT.input_not_inverted()},
            pitchrate_rps: {1, -3.14, 0, 3.14, CCT.input_inverted()},
            throttle_scaled: {2, 0, 0.5, 1.0, CCT.input_not_inverted()},
            yawrate_rps: {3, -3.14, 0.5, 3.14, CCT.input_not_inverted()}
          }
        },
        universal_channel_number_min_mid_max: %{
          flaps_scaled: {4, 0, 0.5, 1.0, CCT.input_inverted()},
          gear_scaled: {5, 0, 0.5, 1.0, CCT.input_inverted()},
          pilot_control_level: {7, -1.0, 0, 1.0, CCT.input_inverted()},
          autopilot_control_mode: {11, -1.0, 0, 1.0, CCT.input_inverted()}
        }
        #   command_limits_min_max: %{
        #     course_rate_rps: {-0.52,0.52},
        #     altitude_mps: {-1.0, 2.0},
        #     speed_mps: {0, 30.0},
        #     sideslip_rad: {-0.26, 0.26},
        #     roll_rad: {-1.05, 1.05},
        #     pitch_rad: {-0.52, 0.52},
        #     yawrate_rps: {-3.14, 3.14},
        #     rollrate_rps: {-6.28, 6.28},
        #     pitchrate_rps: {-3.14, 3.14},
        #     throttle_scaled: {0, 1.0},
        #     flaps_scaled: {0, 1.0},
        #     gear_scaled: {0, 1.0}
        #   }
      ]
    ]
  end
end
