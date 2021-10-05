defmodule Uart.Gps do
  use GenServer
  use Bitwise
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require Ubx.ClassDefs
  require Ubx.Nav.Pvt, as: Pvt
  require Ubx.Nav.Relposned, as: Relposned

  def start_link(config) do
    Logger.debug("Start Uart.Gps with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      expected_antenna_distance_m: Keyword.get(config, :expected_antenna_distance_m, 0),
      antenna_distance_error_threshold_m:
        Keyword.get(config, :antenna_distance_error_threshold_m, -1)
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})

    Logger.debug("Uart.Gps #{uart_port} setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.error("gps terminate")
    Circuits.UART.close(state.uart_ref)

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
    # Logger.debug("rx'd data: #{inspect(data)}")
    ubx =
      UbxInterpreter.check_for_new_messages_and_process(
        state.ubx,
        :binary.bin_to_list(data),
        &process_data_fn/5,
        [
          state.expected_antenna_distance_m,
          state.antenna_distance_error_threshold_m
        ]
      )

    {:noreply, %{state | ubx: ubx}}
  end

  @spec process_data_fn(integer(), integer(), list(), float(), float()) :: atom()
  def process_data_fn(
        msg_class,
        msg_id,
        payload,
        expected_antenna_distance_m,
        antenna_distance_error_threshold_m
      ) do
    # Logger.debug("class/id: #{msg_class}/#{msg_id}"

    case msg_class do
      Ubx.ClassDefs.nav() ->
        case msg_id do
          Pvt.id() ->
            values =
              UbxInterpreter.deconstruct_message_to_map(
                Pvt.bytes(),
                Pvt.multipliers(),
                Pvt.keys(),
                payload
              )


            position_rrm =
              ViaUtils.Location.new_degrees(
                values.latitude_deg,
                values.longitude_deg,
                values.height_m
              )

            velocity_mps = %{
              north_mps: values.v_north_mps,
              east_mps: values.v_east_mps,
              down_mps: values.v_down_mps
            }

            # Logger.debug("NAVPVT itow/fix: #{values.itow_s}/#{values.fix_type}")
            # Logger.debug("pos: #{ViaUtils.Location.to_string(position_rrm)}")
            # Logger.debug("dt/accel/gyro values: #{inspect(values)}")
            if values.fix_type > 1 and values.fix_type < 5 do
              ViaUtils.Comms.send_global_msg_to_group(
                __MODULE__,
                {Groups.gps_itow_position_velocity_val(), values.itow_s, position_rrm, velocity_mps},
                self()
              )
            end

          Relposned.id() ->
            values =
              UbxInterpreter.deconstruct_message_to_map(
                Relposned.bytes(),
                Relposned.multipliers(),
                Relposned.keys(),
                payload
              )

            rel_distance_m = values.rel_pos_length_m + values.rel_pos_hp_length_m
            # Logger.debug("RELPOSNED itow: #{values.itow_s}")
            # Logger.debug("flags/dist: #{values.flags}/#{rel_distance_m}")

            if (values.flags &&& 261) == 261 and
                 abs(rel_distance_m - expected_antenna_distance_m) <
                   antenna_distance_error_threshold_m do
              rel_heading_rad = values.rel_pos_heading_deg |> ViaUtils.Math.deg2rad()

              ViaUtils.Comms.send_global_msg_to_group(
                __MODULE__,
                {Groups.gps_itow_relheading_val(), values.itow_s, rel_heading_rad},
                self()
              )
            end

          _other ->
            Logger.warn("Bad message id: #{msg_id}")
        end

      _other ->
        Logger.warn("Bad message class: #{msg_class}")
    end
  end
end
