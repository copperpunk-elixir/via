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
      if ViaUtils.File.target?() do
        GenServer.cast(__MODULE__, :configure_network)
        Network.Utils.Target
      else
        Logger.debug("Host. No need to configure network.")
        Network.Utils.Host
      end

    check_network_timer =
      ViaUtils.Process.start_loop(
        self(),
        1000,
        @check_network_loop
      )

    state = %{
      network_config: Keyword.get(config, :network_config, []),
      network_utils_module: network_utils_module,
      ip_address: nil,
      check_network_timer: check_network_timer
    }

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

    check_network_timer =
      cond do
        is_nil(state.ip_address) and !is_nil(ip_address) ->
          Logger.debug("new ip address: #{inspect(ip_address)}")

          ip_address = Enum.join(Tuple.to_list(ip_address), ".")

          ViaUtils.Comms.send_local_msg_to_group(
            __MODULE__,
            {:host_ip_address_updated, ip_address},
            self()
          )

          ViaUtils.Process.stop_loop(state.check_network_timer)

          ViaUtils.Process.start_loop(
            self(),
            10000,
            @check_network_loop
          )

        !is_nil(state.ip_address) and is_nil(ip_address) ->
          Logger.warn("Network was up, but now it is down.")
          ViaUtils.Process.stop_loop(state.check_network_timer)

          ViaUtils.Process.start_loop(
            self(),
            1000,
            @check_network_loop
          )

        true ->
          Logger.debug("Check network. Status unchanged.")
          state.check_network_timer
      end

    {:noreply, %{state | ip_address: ip_address, check_network_timer: check_network_timer}}
  end
end
