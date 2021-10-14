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

    [
      Navigator: [
        goals_sorter_classification_and_time_validity_ms:
          navigator_pilot_goals_sorter_classification_and_time_validity_ms,
        path_type: "Dubins",
        path_follower_params: [
          {PFV.k_path(), 0.05},
          {PFV.k_orbit(), 3.5},
          {PFV.chi_inf_rad(), 0.52},
          {PFV.lookahead_dt_s(), 0.5}
        ]
      ]
    ]
  end
end
