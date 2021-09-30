defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Display do
  @spec config() :: list()
  def config() do
    [
      display_module: ViaDisplayScenic,
      realflight_sim: false
    ]
  end
end
