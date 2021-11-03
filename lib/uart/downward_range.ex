defmodule Uart.DownwardRange do
  use Bitwise
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups

  def start_link(config) do
    Logger.debug("Start Uart.DownwardRange")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)

    device_module = Keyword.fetch!(config, :device_module)

    uart_port = Keyword.fetch!(config, :uart_port)

    state = %{
      uart_ref: nil,
      uart_port: uart_port,
      device: apply(device_module, :new, [])
    }

    if uart_port == "virtual" do
      Logger.debug("#{__MODULE__} virtual UART port")
      ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_downward_range())
    else
      port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
      GenServer.cast(self(), {:open_uart_connection, uart_port, port_options, false})
    end

    Logger.debug("Uart.DownwardRange setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    unless is_nil(Map.get(state, :uart_ref)) do
      Circuits.UART.close(state.uart_ref)
    end

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
  def handle_cast({:write, range}, state) do
    %{uart_port: uart_port, device: device} = state

    msg =
      apply(device.__struct__, :create_message_for_range_m, [range])
      |> :binary.list_to_bin()

    if uart_port == "virtual" do
      send(self(), {:circuits_uart, 0, msg})
    else
      Circuits.UART.write(state.uart_ref, msg)
    end

    #    Circuits.UART.drain(state.uart_ref)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("DW range data received: #{data}")
    %{device: device} = state

    {device, range} = apply(device.__struct__, :check_for_new_range, [device, data])
    # Logger.debug("DW range: #{range}")

    device =
      if is_nil(range) do
        device
      else
        ViaUtils.Comms.cast_global_msg_to_group(
          __MODULE__,
          {Groups.downward_range_distance_val(), range},
          self()
        )

        apply(device.__struct__, :clear, [device])
      end

    {:noreply, %{state | device: device}}
  end
end
