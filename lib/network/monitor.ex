defmodule Network.Monitor do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups

  @check_network_loop :check_network_loop

  def start_link(config) do
    Logger.debug("Start Network.Monitor with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.get_host_ip_address())

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
    apply(state.network_utils_module, :configure_network, [state.network_config])
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({Groups.get_host_ip_address(), from}, state) do
    Logger.debug("RF rx get_host_ip: #{state.ip_address}")

    GenServer.cast(from, {Groups.host_ip_address(), state.ip_address})

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@check_network_loop, state) do
    ip_address =
      case apply(state.network_utils_module, :get_ip_address, []) do
        nil -> nil
        valid_ip -> Enum.join(Tuple.to_list(valid_ip), ".")
      end

    check_network_timer =
      cond do
        is_nil(state.ip_address) and !is_nil(ip_address) ->
          Logger.debug("new ip address: #{inspect(ip_address)}")

          ViaUtils.Comms.cast_local_msg_to_group(
            __MODULE__,
            {Groups.host_ip_address(), ip_address},
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
