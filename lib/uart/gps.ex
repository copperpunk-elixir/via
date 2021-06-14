defmodule Uart.Gps do
  use GenServer
  use Bitwise
  require Logger
  require Ubx.MessageDefs

  def start_link(config) do
    Logger.debug("Start Uart.Gps with config: #{inspect(config)}")
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
    Comms.Supervisor.start_operator(__MODULE__)

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    uart_ref = UtilsUart.open_connection_and_return_uart_ref(
      uart_port,
      port_options
    )

    state = %{
      uart_ref: uart_ref,
      ubx: UbxInterpreter.new(),
      expected_antenna_distance_m: Keyword.get(config, :expected_antenna_distance_m, 0),
      antenna_distance_error_threshold_m:
        Keyword.get(config, :antenna_distance_error_threshold_m, -1)
    }

    Logger.debug("Uart.Gps #{uart_port} setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    ubx =
      UbxInterpreter.check_for_new_messages_and_process(state.ubx, :binary.bin_to_list(data), &process_data_fn/5, [
        state.expected_antenna_distance_m,
        state.antenna_distance_error_threshold_m
      ])

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
    # Logger.debug("class/id: #{msg_class}/#{msg_id}")

    case msg_class do
      0x01 ->
        case msg_id do
          0x07 ->
            # _gnd_speed,
            # _hdg_mot,
            # _spd_acc,
            # _hdg_acc,
            # _pdop,
            # _flags3,
            # _res1,
            # _hdg_veh,
            # _mag_dec,
            # _mag_acc
            [
              itow_ms,
              _year,
              _month,
              _day,
              _hour,
              _min,
              _sec,
              _valid,
              _t_acc,
              _nano,
              fix_type,
              _flags,
              _flags2,
              _num_sv,
              lon_deg_e7,
              lat_deg_e7,
              height_mm,
              _height_msl,
              _h_acc_mm,
              _v_acc_mm,
              v_north_mmps,
              v_east_mmps,
              v_down_mmps
            ] = UbxInterpreter.deconstruct_message(Ubx.MessageDefs.nav_pvt_bytes(), payload)

            position_rrm =
              Common.Utils.LatLonAlt.new_deg(
                lat_deg_e7 * 1.0e-7,
                lon_deg_e7 * 1.0e-7,
                height_mm * 1.0e-3
              )

            velocity_mps = %{
              north: v_north_mmps * 1.0e-3,
              east: v_east_mmps * 1.0e-3,
              down: v_down_mmps * 1.0e-3
            }

            # Logger.debug("NAVPVT itow: #{itow_ms}")
            # Logger.debug("pos: #{Common.Utils.LatLonAlt.to_string(position_rrm)}")
            # Logger.debug("dt/accel/gyro values: #{inspect([dt, ax, ay, az, gx, gy, gz])}")
            if fix_type > 1 and fix_type < 5 do
              Comms.Operator.send_local_msg_to_group(
                __MODULE__,
                {:gps_itow_position_velocity, itow_ms, position_rrm, velocity_mps},
                self()
              )
            end

          0x3C ->
            [
              _,
              _,
              _,
              itow_ms,
              _,
              _,
              _,
              rel_pos_length_cm,
              rel_pos_heading_deg_e5,
              _,
              _,
              _,
              _,
              rel_pos_length_mm_e1,
              _,
              _,
              _,
              _,
              _,
              _,
              flags
            ] = UbxInterpreter.deconstruct_message(Ubx.MessageDefs.nav_relposned_bytes(), payload)

            rel_distance_m = rel_pos_length_cm * 0.01 + rel_pos_length_mm_e1 * 1.0e-4
            # Logger.debug("RELPOSNED itwo: #{itow_ms}")
            # Logger.debug("flags/dist: #{flags}/#{rel_distance_m}")

            if (flags &&& 261) == 261 and
                 abs(rel_distance_m - expected_antenna_distance_m) <
                   antenna_distance_error_threshold_m do
              rel_heading_rad = (rel_pos_heading_deg_e5 * 1.0e-5) |> UtilsMath.deg2rad()

              Comms.Operator.send_local_msg_to_group(
                __MODULE__,
                {:gps_itow_relheading},
                [itow_ms, rel_heading_rad],
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
