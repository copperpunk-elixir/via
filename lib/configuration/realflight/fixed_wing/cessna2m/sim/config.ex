defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Config do
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
      :Simulation,
      :Uart
    ]
  end
end
