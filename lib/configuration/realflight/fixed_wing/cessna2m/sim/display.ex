defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Display do
  @spec config() :: list()
  def config() do
    [
      display_module: ViaDisplayScenic,
      realflight_sim: true
    ]
  end
end
