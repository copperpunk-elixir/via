defmodule Configuration.FixedWing.Cessna2m.Node1.Navigation do
  require ViaNavigation.Dubins.Shared.PathFollowerValues, as: PFV
  require Comms.Sorters

  @spec config() :: list()
  def config() do
        [
      Navigator: [
       path_type: "Dubins",
        path_follower_params: [
          {PFV.k_path(), 10.025},
          {PFV.k_orbit(), 20.0},
          {PFV.chi_inf_rad(), 10.04},
          {PFV.lookahead_dt_s(), 10.0}
        ]
      ]
    ]
  end
end
