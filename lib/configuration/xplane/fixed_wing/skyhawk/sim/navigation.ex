defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Navigation do
  require ViaNavigation.Dubins.Shared.PathFollowerValues, as: PFV
  require Comms.Sorters

  @spec config() :: list()
  def config() do
    message_sorter_module = Configuration.Utils.get_message_sorter_module(__MODULE__)

    navigator_pilot_goals_sorter_classification_and_time_validity_ms =
      apply(message_sorter_module, :message_sorter_classification_time_validity_ms, [
        Navigation.Navigator,
        Comms.Sorters.pilot_control_level_and_goals()
      ])

    vehicle_type = Module.split(__MODULE__) |> Enum.at(2)

    [
      Navigator: [
        goals_sorter_classification_and_time_validity_ms:
          navigator_pilot_goals_sorter_classification_and_time_validity_ms,
        path_type: "Dubins",
        vehicle_type: vehicle_type,
        takeoff_flaps_speed_min_mps: 41,
        landing_flaps_speed_min_mps: 36,
        gear_agl_min_m: 20,
        path_follower_params: [
          {PFV.k_path(), 0.015},
          {PFV.k_orbit(), 3.5},
          {PFV.chi_inf_rad(), 1.04},
          {PFV.lookahead_dt_s(), 2.0}
        ]
      ]
    ]
  end
end
