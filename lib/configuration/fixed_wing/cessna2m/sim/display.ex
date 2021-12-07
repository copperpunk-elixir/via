defmodule Configuration.FixedWing.Cessna2m.Sim.Display do
  @spec config() :: list()
  def config() do
    [
      Operator: [
        port_options: [speed: 115_200],
        uart_port: "virtual"
      ],
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: true
    ]
  end
end
