defmodule Peripherals.Uart.Companion do
  use GenServer
  require Logger
  require Ubx.MessageDefs

  @spec start_link(keyword) :: {:ok, any}
  def start_link(config) do
    Logger.debug("Start Uart.Companion")
    {:ok, process_id} = UtilsProcess.start_link_redundant(GenServer, __MODULE__, nil)
    GenServer.cast(__MODULE__, {:begin, config})
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
    # Logger.warn("Companion config begin: #{inspect(config)}")
    Comms.System.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, :gps_time, self())

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    uart_ref = UtilsUart.open_connection_and_return_uart_ref(
      uart_port,
      port_options
    )

    state = %{
      uart_ref: uart_ref,
      ubx: UbxInterpreter.new(),
      accel_counts_to_mpss: Keyword.fetch!(config, :accel_counts_to_mpss),
      gyro_counts_to_rps: Keyword.fetch!(config, :gyro_counts_to_rps)
    }

    Logger.debug("Uart.Companion.Operator #{uart_port} setup complete!")
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
    ubx =
      UbxInterpreter.check_for_new_messages_and_process(state.ubx, :binary.bin_to_list(data), &process_data_fn/5, [
        state.accel_counts_to_mpss,
        state.gyro_counts_to_rps
      ])

    {:noreply, %{state | ubx: ubx}}
  end

  @spec process_data_fn(integer(), integer(), list(), float(), float()) :: atom()
  def process_data_fn(msg_class, msg_id, payload, accel_counts_to_mpss, gyro_counts_to_rps) do
    case msg_class do
      0x11 ->
        case msg_id do
          0x00 ->
            [dt, ax, ay, az, gx, gy, gz] =
              UbxInterpreter.deconstruct_message(Ubx.MessageDefs.dt_accel_gyro_val_bytes(), payload)

            # Logger.debug("dt/accel/gyro values: #{inspect([dt, ax, ay, az, gx, gy, gz])}")
            values = [
              dt * 1.0e-6,
              ax * accel_counts_to_mpss,
              ay * accel_counts_to_mpss,
              az * accel_counts_to_mpss,
              gx * gyro_counts_to_rps,
              gy * gyro_counts_to_rps,
              gz * gyro_counts_to_rps
            ]

            # Logger.debug("dt/accel/gyro values: #{UtilsFormat.eftb_list(values, 3)}")
            Comms.Operator.send_local_msg_to_group(
              __MODULE__,
              {:dt_accel_gyro_val, values},
              self()
            )

          _other ->
            Logger.warn("Bad message id: #{msg_id}")
        end

      _other ->
        Logger.warn("Bad message class: #{msg_class}")
    end
  end

  @spec send_message(binary()) :: atom()
  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

end
