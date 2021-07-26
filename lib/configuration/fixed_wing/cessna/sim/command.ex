defmodule Configuration.FixedWing.Cessna.Sim.Command do
  require Command.ControlTypes, as: CCT
  require Comms.Sorters, as: Sorters
  require Command.ActuatorNames, as: Act

  @spec config() :: list()
  def config() do
    message_sorter_module =
      Module.split(__MODULE__)
      |> Enum.drop(-1)
      |> Module.concat()
      |> Module.concat(MessageSorter)

    remote_pilot_goals_sorter_classification_and_time_validity_ms =
      apply(message_sorter_module, :message_sorter_classification_time_validity_ms, [
        Command.RemotePilot,
        Sorters.pilot_control_level_and_goals()
      ])

    [
      Commander: [],
      RemotePilot: [
        num_channels: 12,
        control_level_dependent_channel_config: %{
          CCT.pilot_control_level_4() => %{
            course_rate_rps: {0, {-0.52, 0, 0.52, CCT.input_not_inverted(), 0.017}},
            altitude_rate_mps: {1, {-1.0, 0, 2.0, CCT.input_inverted(), 0.05}},
            groundspeed_mps: {2, {0, 15.0, 30.0, CCT.input_not_inverted(), 0}},
            sideslip_rad: {3, {-0.26, 0, 0.26, CCT.input_not_inverted(), 0.017}}
          },
          CCT.pilot_control_level_2() => %{
            roll_rad: {0, {-1.05, 0, 1.05, CCT.input_not_inverted(), 0.017}},
            pitch_rad: {1, {-0.52, 0, 0.52, CCT.input_inverted(), 0.017}},
            thrust_scaled: {2, {0, 0.5, 1.0, CCT.input_not_inverted(), 0.01}},
            deltayaw_rad: {3, {-0.26, 0, 0.26, CCT.input_not_inverted(), 0.087}}
          },
          CCT.pilot_control_level_1() => %{
            rollrate_rps: {0, {-6.28, 0, 6.28, CCT.input_not_inverted(), 0.087}},
            pitchrate_rps: {1, {-3.14, 0, 3.14, CCT.input_inverted(), 0.087}},
            throttle_scaled: {2, {0, 0.5, 1.0, CCT.input_not_inverted(), 0.01}},
            yawrate_rps: {3, {-3.14, 0.0, 3.14, CCT.input_not_inverted(), 0.087}}
          }
        },
        all_levels_channel_config: %{
          flaps_scaled: {4, {0, 0.5, 1.0, CCT.input_not_inverted(), 0.01}},
          gear_scaled: {5, {0, 0.5, 1.0, CCT.input_inverted(), 0.01}},
          pilot_control_level: {6, {-1.0, 0, 1.0, CCT.input_inverted(), 0}},
          autopilot_control_mode: {11, {-1.0, 0, 1.0, CCT.input_inverted(), 0}}
        },
        remote_pilot_override_channels: %{
          Act.aileron() => {0, :two_sided},
          Act.elevator() => {1, :two_sided},
          Act.throttle() => {2, :one_sided},
          Act.rudder() => {3, :two_sided},
          Act.flaps() => {4, :one_sided},
          Act.gear() => {5, :one_sided}
        },
        goals_sorter_classification_and_time_validity_ms:
          remote_pilot_goals_sorter_classification_and_time_validity_ms
      ]
    ]
  end
end
