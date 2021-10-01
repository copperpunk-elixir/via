defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Display do
  @spec config() :: list()
  def config() do
    [
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: true
    ]
  end
end
