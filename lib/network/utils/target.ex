defmodule Network.Utils.Target do
  require Logger
  @wireless_interfaces ["wlan0"]
  @mount_path "/mnt"

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
    ssid_psk = check_data_directory_for_credentials()

    {ssid, psk} =
      if is_nil(ssid_psk) do
        Logger.warn("Wifi config not found in data folder. Checking USB drive")
        ViaUtils.File.mount_usb_drive("sda1", @mount_path)
        {:ok, ssid_psk} = File.read(@mount_path <> "/network.txt")
        ViaUtils.File.unmount_usb_drive(@mount_path)
        File.write("/data/network.txt", ssid_psk)
        split_ssid_psk_binary(ssid_psk)
      else
        Logger.warn("Wifi config IS found in data folder. #{ssid_psk}")
        split_ssid_psk_binary(ssid_psk)
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

  def check_data_directory_for_credentials() do
    case File.read("/data/network.txt") do
      {:ok, ssid_psk} -> ssid_psk
      _other -> nil
    end
  end

  def split_ssid_psk_binary(ssid_psk) do
    [ssid, psk] = String.split(ssid_psk, ",")
    psk = String.trim_trailing(psk, "\n")
    {ssid, psk}
  end
end
