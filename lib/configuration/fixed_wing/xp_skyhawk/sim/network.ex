defmodule Configuration.FixedWing.XpSkyhawk.Sim.Network do
  @spec config() :: list()
  def config() do
    [
      Monitor: [
        network_config: [
          # {"usb0", %{type: VintageNetDirect}},
          # {"eth0",
          #  %{
          #    type: VintageNetEthernet,
          #    ipv4: %{method: :dhcp}
          #  }},
          {"wlan0", %{type: VintageNetWiFi, ipv4: %{method: :dhcp}}}
        ]
      ]
    ]
  end
end
