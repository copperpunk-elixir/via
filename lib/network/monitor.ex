defmodule Network.Monitor do
  use GenServer
  require Logger

  @wireless_interfaces ["wlan0"]
  @mount_path "/mnt"

  def start_link(config) do
    Logger.debug("Start Network.Monitor with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    state = %{
      network_config: Keyword.get(config, :network_config, [])
    }

    if Via.Application.target?() do
      GenServer.cast(__MODULE__, :configure_network)
    else
      Logger.debug("Host. No need to configure network.")
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:configure_network, state) do
    Enum.each(state.network_config, fn {interface, config} ->
      config =
        if String.contains?(interface, @wireless_interfaces) do
          Map.put(config, :vintage_net_wifi, get_wifi_config())
        end

      Logger.debug("network config: #{inspect(config)}")
      result = VintageNet.configure(interface, config)
      Logger.debug("Configure #{interface}: #{inspect(result)}")
    end)

    {:noreply, state}
  end

  @spec get_wifi_config() :: map()
  def get_wifi_config() do
    ViaUtils.File.mount_usb_drive("sda1", @mount_path)
    {:ok, ssid_psk} = File.read(@mount_path <> "/network.txt")
    [ssid, psk] = String.split(ssid_psk, ",")
    psk = String.trim_trailing(psk, "\n")
    ViaUtils.File.unmount_usb_drive(@mount_path)

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

  @spec configure_wifi(binary(), binary()) :: any()
  def configure_wifi(ssid, psk) do
  end
end
