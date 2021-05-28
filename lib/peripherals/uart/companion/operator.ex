defmodule Peripherals.Uart.Companion.Operator do
  use GenServer
  require Logger
  require Ubx.MessageDefs
  require Common.Constants, as: CC

  @accel_counts_to_mpss CC.gravity() / 8192
  @gyro_counts_to_rps CC.deg2rad() / 16.4

  @spec start_link(keyword) :: {:ok, any}
  def start_link(config) do
    Logger.debug("Start Uart.Companion.Operator")
    # Logger.debug("config: #{inspect(config)}")
    # Logger.info("new config: #{inspect(config)}")
    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil)
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
    {:ok, uart_ref} = Circuits.UART.start_link()

    state = %{
      uart_ref: uart_ref,
      ubx: Ubx.Interpreter.new(),
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(
      state.uart_ref,
      uart_port,
      port_options
    )

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
      Ubx.Interpreter.process_data(state.ubx, :binary.bin_to_list(data), &process_data_fn/3, [])

    {:noreply, %{state | ubx: ubx}}
  end

  @spec process_data_fn(integer(), integer(), list()) :: atom()
  def process_data_fn(msg_class, msg_id, payload) do
    case msg_class do
      0x11 ->
        case msg_id do
          0x00 ->
            [dt, ax, ay, az, gx, gy, gz] =
              Ubx.Utils.deconstruct_message(Ubx.MessageDefs.dt_accel_gyro_val_bytes(), payload)

            # Logger.debug("dt/accel/gyro values: #{inspect([dt, ax, ay, az, gx, gy, gz])}")
            values = [
              dt * 1.0e-6,
              ax * @accel_counts_to_mpss,
              ay * @accel_counts_to_mpss,
              az * @accel_counts_to_mpss,
              gx * @gyro_counts_to_rps,
              gy * @gyro_counts_to_rps,
              gz * @gyro_counts_to_rps
            ]

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
