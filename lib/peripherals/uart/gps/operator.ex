defmodule Peripherals.Uart.Gps.Operator do
  use GenServer
  use Bitwise
  require Logger
  require Ubx.MessageDefs
  require Common.Constants, as: CC

  def start_link(config) do
    Logger.debug("Start Uart.Gps.Operator")
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
    Comms.System.start_operator(__MODULE__)
    {:ok, uart_ref} = Circuits.UART.start_link()

    state = %{
      uart_ref: uart_ref,
      ubx: Ubx.Interpreter.new()
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(
      state.uart_ref,
      uart_port,
      port_options
    )

    Logger.debug("Uart.Gps.Operator #{uart_port} setup complete!")
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
            ] =
              Ubx.Utils.deconstruct_message(Ubx.MessageDefs.nav_pvt_bytes(), payload)

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

            Logger.debug("NAVPVT itow: #{itow_ms}")
            Logger.debug("pos: #{Common.Utils.LatLonAlt.to_string(position_rrm)}")
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
            ] = Ubx.Utils.deconstruct_message(Ubx.MessageDefs.nav_relposned_bytes(), payload)

            rel_distance_m = rel_pos_length_cm * 0.01 + rel_pos_length_mm_e1 * 1.0e-4
            Logger.debug("RELPOSNED itwo: #{itow_ms}")
            Logger.debug("flags/dist: #{flags}/#{rel_distance_m}")

            if (flags &&& 261) == 261 do
              rel_heading_rad = (rel_pos_heading_deg_e5 * 1.0e-5) |> Common.Utils.Math.deg2rad()

              Comms.Operator.send_local_msg_to_group(
                __MODULE__,
                {:gps_itow_relheading_reldistance},
                [itow_ms, rel_heading_rad, rel_distance_m],
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
