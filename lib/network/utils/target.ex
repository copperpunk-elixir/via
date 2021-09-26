defmodule Network.Utils.Target do
  require Logger
  require ViaUtils.File
  require Configuration.Filenames, as: Filenames

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
        Filenames.network(),
        ViaUtils.File.default_mount_path(),
        true,
        true
      )

    cond do
      is_nil(ssid_psk) ->
        Logger.error("Wifi Network configuration could not be located")
        %{}

      ssid_psk == "" ->
        Logger.debug("Removing Wifi credentials")
        %{}

      true ->
        [ssid, psk] = String.split(ssid_psk, ",")
        Logger.debug("Network ssid/psk: #{ssid}/#{psk}")

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
end
