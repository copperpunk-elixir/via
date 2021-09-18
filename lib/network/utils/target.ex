defmodule Network.Utils.Target do
  require Logger
  require ViaUtils.File

  @wireless_interfaces ["wlan0"]

  @spec get_ip_address() :: any()
  def get_ip_address() do
    get_ip_address_for_interfaces(VintageNet.all_interfaces())
  end

  @spec get_ip_address_for_interfaces(list()) :: any()
  def get_ip_address_for_interfaces(interfaces) do
    {[interface], remaining} = Enum.split(interfaces, 1)
    all_ip_configs = VintageNet.get(["interface", interface, "addresses"], [])
    # Logger.debug("all ip configs: #{inspect(all_ip_configs)}")
    ip_config =
      Enum.find(all_ip_configs, fn ip_config ->
        ip_config.family == :inet and ip_config.address != {127, 0, 0, 1}
      end)

    cond do
      !is_nil(ip_config) -> ip_config.address
      Enum.empty?(remaining) -> nil
      true -> get_ip_address_for_interfaces(remaining)
    end
  end

  @spec configure_network(list()) :: atom()
  def configure_network(network_config) do
    Enum.each(network_config, fn {interface, config} ->
      config =
        if String.contains?(interface, @wireless_interfaces) do
          Map.put(config, :vintage_net_wifi, get_wifi_config())
        end

      Logger.debug("network config: #{inspect(config)}")
      result = VintageNet.configure(interface, config)
      Logger.debug("Configure #{interface}: #{inspect(result)}")
    end)
  end

  @spec get_wifi_config() :: map()
  def get_wifi_config() do
    ssid_psk =
      ViaUtils.File.read_file_target(
        "network.txt",
        ViaUtils.File.default_mount_path(),
        true,
        true
      )

    [ssid, psk] =
      if is_nil(ssid_psk) do
        raise "Wifi Network configuration could not be located"
      else
        String.split(ssid_psk, ",")
      end

    %{
      networks: [
        %{
          key_mgmt: :wpa_psk,
          psk: psk,
          ssid: ssid
        }
      ]
    }
  end
end
