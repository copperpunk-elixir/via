defmodule Peripherals.Uart.Generic.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Uart.Generic.Operator")
    # Logger.debug("config: #{inspect(config)}")
    name = via_tuple(Keyword.fetch!(config, :uart_port))
    # Logger.debug("Generic.Operator name: #{inspect(name)}")
    config = Keyword.put(config, :name, name)
    # Logger.info("new config: #{inspect(config)}")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil, name)
    GenServer.cast(name, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Circuits.UART.close(state.uart_ref)
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    # Logger.warn("generic config begin: #{inspect(config)}")
    name = Keyword.fetch!(config, :name)
    Comms.System.start_operator(name)
    Comms.Operator.join_group(name, :gps_time, self())
    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      name: name,
      uart_ref: uart_ref,
      ubx: Ubx.Interpreter.new(),
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Generic.Operator #{uart_port} setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_message, message}, state) do
    Circuits.UART.write(state.uart_ref, message)
    {:noreply, state}
  end

    @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    ublox = Ubx.Utils.parse(state.ublox, :binary.bin_to_list(data), state.name, state.sorter_classification)
    {:noreply, %{state | ublox: ublox}}
  end

  @spec via_tuple(binary()) :: tuple()
  def via_tuple(uart_port) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,uart_port)
  end

end
