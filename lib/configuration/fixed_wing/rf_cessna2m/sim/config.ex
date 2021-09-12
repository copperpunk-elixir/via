defmodule Configuration.FixedWing.RfCessna2m.Sim.Config do
  require Logger

  def modules() do
    [
      :Command,
      :Control,
      :Display,
      :Estimation,
      :MessageSorter,
      :Simulation
    ]
  end
end
