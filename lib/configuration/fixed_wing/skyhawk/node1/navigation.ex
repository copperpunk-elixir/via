defmodule Configuration.FixedWing.Skyhawk.Node1.Navigation do
  require ViaNavigation.Dubins.Shared.PathFollowerValues, as: PFV
  require Comms.Sorters

  @spec config() :: list()
  def config() do
    []
  end
end
