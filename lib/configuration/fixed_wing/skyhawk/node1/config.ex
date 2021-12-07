defmodule Configuration.FixedWing.Skyhawk.Node1.Config do
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
