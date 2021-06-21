defmodule Uart.CommandRx do
  use Bitwise
  use GenServer
  require Logger
  require Comms.Groups, as: Groups

  # @default_baud 115_200

  def start_link(config) do
    Logger.debug("Start Uart.CommandRx")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    Comms.Supervisor.start_operator(__MODULE__)
    rx_module = Keyword.fetch!(config, :rx_module)
    Logger.debug("Rx module: #{rx_module}")

    state = %{
      uart_ref: nil,
      channel_values: [],
      rx_module: rx_module,
      rx: apply(rx_module, :new, [])
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})

    Logger.debug("Uart.CommandRx #{uart_port} setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:open_uart_connection, uart_port, port_options}, state) do
    uart_ref =
      ViaUtils.Uart.open_connection_and_return_uart_ref(
        uart_port,
        port_options
      )

    {:noreply, %{state | uart_ref: uart_ref}}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("data: #{inspect(data)}")
    {rx, channel_values} = apply(state.rx_module, :check_for_new_messages, [state.rx, :binary.bin_to_list(data)])

    rx =
      if !Enum.empty?(channel_values) do
        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          {Groups.command_channels_failsafe, channel_values, false},
          self()
        )
        # Logger.debug("channels: #{ViaUtils.Format.eftb_list(channel_values, 3, ",")}")
        apply(state.rx_module, :clear, [rx])
      else
        rx
      end

    {:noreply, %{state | rx: rx, channel_values: channel_values}}
  end
end
