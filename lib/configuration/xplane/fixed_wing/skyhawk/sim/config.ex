defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Config do
  require Logger

  def modules() do
    [
      :Command,
      :Control,
      :Display,
      :Estimation,
      :MessageSorter,
      :Navigation,
      :Network,
      :Simulation
    ]
  end
end
