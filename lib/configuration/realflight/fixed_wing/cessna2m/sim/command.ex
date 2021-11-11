defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Command do
  require ViaUtils.Shared.ControlTypes, as: CCT
  require ViaUtils.Shared.GoalNames, as: SGN
  require Comms.Sorters, as: Sorters

  @spec config() :: list()
  def config() do
    message_sorter_module = Configuration.Utils.get_message_sorter_module(__MODULE__)

    remote_pilot_goals_sorter_classification_and_time_validity_ms =
      apply(message_sorter_module, :message_sorter_classification_time_validity_ms, [
        Command.RemotePilot,
        Sorters.pilot_control_level_and_goals()
      ])

    [
      Commander: [],
      RemotePilot: [
        num_channels: 10,
        current_pcl_channel_config: %{
          CCT.pilot_control_level_4() => %{
            SGN.course_rate_rps() => {0, {-0.52, 0, 0.52, CCT.input_not_inverted(), 0.052}},
            SGN.altitude_rate_mps() => {1, {-5.0, 0, 5.0, CCT.input_inverted(), 0.05}},
            SGN.groundspeed_mps() => {2, {0, 10, 20.0, CCT.input_not_inverted(), 0}},
            SGN.sideslip_rad() => {3, {-0.26, 0, 0.26, CCT.input_not_inverted(), 0.052}}
          },
          CCT.pilot_control_level_2() => %{
            SGN.roll_rad() => {0, {-1.05, 0, 1.05, CCT.input_not_inverted(), 0.017}},
            SGN.pitch_rad() => {1, {-0.52, 0, 0.52, CCT.input_inverted(), 0.017}},
            SGN.thrust_scaled() => {2, {0, 0.5, 1.0, CCT.input_not_inverted(), 0.01}},
            SGN.deltayaw_rad() => {3, {-0.78, 0, 0.78, CCT.input_not_inverted(), 0.017}}
          },
          CCT.pilot_control_level_1() => %{
            SGN.rollrate_rps() => {0, {-6.28, 0, 6.28, CCT.input_not_inverted(), 0.087}},
            SGN.pitchrate_rps() => {1, {-3.14, 0, 3.14, CCT.input_inverted(), 0.087}},
            SGN.throttle_scaled() => {2, {-1, 0.0, 1.0, CCT.input_not_inverted(), -0.99}},
            SGN.yawrate_rps() => {3, {-3.14, 0.0, 3.14, CCT.input_not_inverted(), 0.087}}
          }
        },
        any_pcl_channel_config: %{
          SGN.flaps_scaled() => {4, {-1, 0.0, 1.0, CCT.input_not_inverted(), -0.99}},
          SGN.gear_scaled() => {9, {-1, 0.0, 1.0, CCT.input_inverted(), -0.99}},
          SGN.pilot_control_level() => {5, {-1.0, 0, 1.0, CCT.input_not_inverted(), 0}},
          SGN.autopilot_control_mode() => {6, {-1.0, 0, 1.0, CCT.input_inverted(), 0}}
        },
        remote_pilot_override_channels: %{
          SGN.aileron_scaled() => 0,
          SGN.elevator_scaled() => 1,
          SGN.throttle_scaled() => 2,
          SGN.rudder_scaled() => 3,
          SGN.flaps_scaled() => 4,
          SGN.gear_scaled() => 9
        },
        goals_sorter_classification_and_time_validity_ms:
          remote_pilot_goals_sorter_classification_and_time_validity_ms
      ]
    ]
  end
end
