defmodule Configuration.RealFlight.FixedWing.Cessna2m.Sim.Config do
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
