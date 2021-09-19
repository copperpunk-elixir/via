defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Network do
  @spec config() :: list()
  def config() do
    [
      Monitor: [
        network_config: [
          {"wlan0", %{type: VintageNetWiFi, ipv4: %{method: :dhcp}}}
        ]
      ]
    ]
  end
end
