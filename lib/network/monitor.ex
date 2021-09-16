defmodule Network.Monitor do
  use GenServer
  require Logger

  @check_network_loop :check_network_loop

  def start_link(config) do
    Logger.debug("Start Network.Monitor with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    network_utils_module =
      if Via.Application.target?() do
        GenServer.cast(__MODULE__, :configure_network)
        Network.Utils.Target
      else
        Logger.debug("Host. No need to configure network.")
        Network.Utils.Host
      end

    state = %{
      network_config: Keyword.get(config, :network_config, []),
      network_utils_module: network_utils_module,
      ip_address: nil
    }

    ViaUtils.Process.start_loop(
      self(),
      1000,
      @check_network_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:configure_network, state) do
    Network.Utils.Target.configure_network(state.network_config)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:resend_ip_address, state) do
    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {:host_ip_address_updated, state.ip_address},
      self()
    )

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@check_network_loop, state) do
    ip_address = apply(state.network_utils_module, :get_ip_address, [])

    if is_nil(state.ip_address) and !is_nil(ip_address) do
      Logger.debug("new ip address: #{inspect(ip_address)}")

      ip_address = Enum.join(Tuple.to_list(ip_address), ".")

      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {:host_ip_address_updated, ip_address},
        self()
      )
    end

    {:noreply, %{state | ip_address: ip_address}}
  end
end
