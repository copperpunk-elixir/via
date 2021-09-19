defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Config do
  require Logger

  def modules() do
    [
      :Command,
      :Control,
      :Display,
      :Estimation,
      :MessageSorter,
      :Network,
      :Simulation
    ]
  end
end
