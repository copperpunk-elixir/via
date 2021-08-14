defmodule Configuration.FixedWing.Cessna.Hil.Config do
  require Logger

  def modules() do
    [
      :Command,
      :Control,
      :Display,
      :Estimation,
      :MessageSorter,
      :Simulation,
      :Uart
    ]
  end

end
