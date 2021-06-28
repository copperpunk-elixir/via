defmodule TestHelper.Uart.GenServer do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start DummyGenServer: #{inspect(config[:name])}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, via_tuple(config[:name]))
  end

  @impl GenServer
  def init(config) do
    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
    Logger.debug("Uart.Companion.Operator #{uart_port} setup complete!")

    {:ok, %{data: [], uart_ref: nil}}
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
  def handle_cast({:send_data, data}, state) do
    Logger.debug("send: #{inspect(data)}")
    Circuits.UART.write(state.uart_ref, :binary.list_to_bin(data))
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")

    {:noreply, %{state | data: state.data ++ :binary.bin_to_list(data)}}
  end

  @impl GenServer
  def handle_call(:get_data, _from, state) do
    {:reply, state.data, %{state | data: []}}
  end

  def send_data(name, data) do
    GenServer.cast(via_tuple(name), {:send_data, data})
  end

  def get_data(name) do
    GenServer.call(via_tuple(name), :get_data)
  end
  def via_tuple(name) do
    ViaUtils.Registry.via_tuple(__MODULE__, name)
  end
end
