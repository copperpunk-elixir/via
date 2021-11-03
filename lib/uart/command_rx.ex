defmodule Uart.CommandRx do
  use Bitwise
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups

  @protocol_id_loop :protocol_id_loop
  @protocol_id_loop_interval_ms 10
  @configure_uart_loop :configure_uart_loop

  def start_link(config) do
    Logger.debug("Start Uart.CommandRx")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)
    rx_module_config = Keyword.fetch!(config, :rx_module_config)

    rxs =
      Enum.reduce(rx_module_config, [], fn {rx_module, _port_options}, acc ->
        acc ++ [apply(rx_module, :new, [])]
      end)

    uart_port = Keyword.fetch!(config, :uart_port)

    state = %{
      uart_ref: nil,
      uart_port: uart_port,
      channel_values: [],
      rx_module_config: rx_module_config,
      rxs: rxs,
      protocol_id_timer: nil,
      configure_uart_timer: nil
    }

    Logger.info("#{__MODULE__} uart port: #{inspect(uart_port)}")

    if uart_port == "virtual" do
      Logger.debug("#{__MODULE__} virtual UART port")
    else
      port_options = Map.get(rx_module_config, Enum.at(rxs, 0).__struct__)
      GenServer.cast(self(), {:open_uart_connection, uart_port, port_options, false})
    end

    Logger.debug("Uart.CommandRx #{uart_port} setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:open_uart_connection, uart_port, port_options, protocol_established}, state) do
    port_options = port_options ++ [active: protocol_established]

    uart_ref =
      ViaUtils.Uart.open_connection_and_return_uart_ref(
        uart_port,
        port_options
      )

    {protocol_id_timer, configure_uart_timer} =
      if !protocol_established do
        {ViaUtils.Process.start_loop(
           self(),
           @protocol_id_loop_interval_ms,
           @protocol_id_loop
         ),
         ViaUtils.Process.start_loop(
           self(),
           1000,
           @configure_uart_loop
         )}
      else
        {nil, nil}
      end

    {:noreply,
     %{
       state
       | uart_ref: uart_ref,
         protocol_id_timer: protocol_id_timer,
         configure_uart_timer: configure_uart_timer
     }}
  end

  @impl GenServer
  def handle_info(@configure_uart_loop, state) do
    {active_rx, remaining_rxs} = List.pop_at(state.rxs, 0)
    rxs = remaining_rxs ++ [active_rx]
    new_port_options = Map.get(state.rx_module_config, Enum.at(rxs, 0).__struct__)

    ViaUtils.Process.stop_loop(state.protocol_id_timer)
    ViaUtils.Process.stop_loop(state.configure_uart_timer)
    restart_uart_port(state.uart_ref, state.uart_port, new_port_options, false)

    {:noreply,
     %{
       state
       | rxs: rxs
     }}
  end

  @impl GenServer
  def handle_info(@protocol_id_loop, state) do
    data =
      unless is_nil(state.uart_ref) do
        case Circuits.UART.read(state.uart_ref, round(@protocol_id_loop_interval_ms / 2)) do
          {:ok, binary} ->
            binary

          {:error, reason} ->
            Logger.error("Uart.CommandRx read error: #{inspect(reason)}")
            []
        end
      else
        []
      end

    {rx, is_valid} = check_for_valid_message(Enum.at(state.rxs, 0), data)

    state =
      if is_valid do
        Logger.debug("Valid Rx found. Switch UART to active")
        ViaUtils.Process.stop_loop(state.protocol_id_timer)
        ViaUtils.Process.stop_loop(state.configure_uart_timer)
        port_options = Circuits.UART.configuration(state.uart_ref) |> elem(1)
        restart_uart_port(state.uart_ref, state.uart_port, port_options, true)

        Map.put(state, :uart_ref, nil)
        |> Map.put(:rx, rx)
        |> Map.delete(:rxs)
      else
        %{state | rxs: List.replace_at(state.rxs, 0, rx)}
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    {rx, channel_values} =
      apply(state.rx.__struct__, :check_for_new_messages, [state.rx, :binary.bin_to_list(data)])

    rx =
      if !Enum.empty?(channel_values) do
        ViaUtils.Comms.cast_local_msg_to_group(
          __MODULE__,
          {Groups.command_channels(), channel_values},
          self()
        )

        # Logger.debug("channels: #{ViaUtils.Format.eftb_list(channel_values, 3, ",")}")
        apply(rx.__struct__, :clear, [rx])
      else
        rx
      end

    {:noreply, %{state | rx: rx, channel_values: channel_values}}
  end

  def restart_uart_port(uart_ref, uart_port, port_options, protocol_established) do
    Circuits.UART.stop(uart_ref)
    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options, protocol_established})
  end

  @spec check_for_valid_message(struct(), binary()) :: tuple
  def check_for_valid_message(rx, data) do
    {rx, channel_values} =
      apply(rx.__struct__, :check_for_new_messages, [rx, :binary.bin_to_list(data)])

    if !Enum.empty?(channel_values) do
      Logger.debug("Valid payload found for #{rx.__struct__}")
      {rx, true}
    else
      {rx, false}
    end
  end
end
