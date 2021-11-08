defmodule Uart.Gps do
  use GenServer
  use Bitwise
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaTelemetry.Ubx.ClassDefs
  require ViaTelemetry.Ubx.Nav.Pvt, as: Pvt
  require ViaTelemetry.Ubx.Nav.Relposned, as: Relposned

  def start_link(config) do
    Logger.debug("Start Uart.Gps with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      expected_gps_antenna_distance_m: Keyword.get(config, :expected_gps_antenna_distance_m, 0),
      gps_antenna_distance_error_threshold_m:
        Keyword.get(config, :gps_antenna_distance_error_threshold_m, -1)
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    Logger.info("Uart.Gps uart port: #{inspect(uart_port)}")

    if uart_port == "virtual" do
      Logger.debug("#{__MODULE__} virtual UART port")
      ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_gps())
    else
      port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
      GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
    end

    Logger.debug("Uart.Gps #{uart_port} setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.error("gps terminate: #{inspect(reason)}")

    unless is_nil(state.uart_ref) do
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
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    %{
      ubx: ubx,
      expected_gps_antenna_distance_m: expected_gps_antenna_distance_m,
      gps_antenna_distance_error_threshold_m: gps_antenna_distance_error_threshold_m
    } = state

    ubx =
      UbxInterpreter.check_for_new_messages_and_process(
        ubx,
        :binary.bin_to_list(data),
        &process_data_fn/5,
        [
          expected_gps_antenna_distance_m,
          gps_antenna_distance_error_threshold_m
        ]
      )

    {:noreply, %{state | ubx: ubx}}
  end

  @spec process_data_fn(integer(), integer(), list(), float(), float()) :: atom()
  def process_data_fn(
        msg_class,
        msg_id,
        payload,
        expected_gps_antenna_distance_m,
        gps_antenna_distance_error_threshold_m
      ) do
    # Logger.debug("class/id: #{msg_class}/#{msg_id}")

    case msg_class do
      ViaTelemetry.Ubx.ClassDefs.nav() ->
        case msg_id do
          Pvt.id() ->
            values =
              UbxInterpreter.deconstruct_message_to_map(
                Pvt.bytes(),
                Pvt.multipliers(),
                Pvt.keys(),
                payload
              )

            %{
              Pvt.iTOW() => itow_ms,
              Pvt.lat() => lat_deg,
              Pvt.lon() => lon_deg,
              Pvt.height() => height_mm,
              Pvt.velN() => v_north_mmps,
              Pvt.velE() => v_east_mmps,
              Pvt.velD() => v_down_mmps,
              Pvt.fixType() => fix_type
            } = values

            position_rrm = ViaUtils.Location.new_degrees(lat_deg, lon_deg, height_mm * 0.001)

            velocity_mps = %{
              SVN.v_north_mps() => v_north_mmps * 0.001,
              SVN.v_east_mps() => v_east_mmps * 0.001,
              SVN.v_down_mps() => v_down_mmps * 0.001
            }

            # Logger.debug("NAVPVT itow/fix: #{itow_ms}/#{fix_type}")
            # Logger.debug("pos: #{ViaUtils.Location.to_string(position_rrm)}")
            # Logger.debug("dt/accel/gyro values: #{inspect(values)}")
            if fix_type > 1 and fix_type < 5 do
              ViaUtils.Comms.cast_global_msg_to_group(
                __MODULE__,
                {Groups.gps_itow_position_velocity_val(),
                 %{
                   SVN.itow_s() => itow_ms * 0.001,
                   SVN.position_rrm() => position_rrm,
                   SVN.velocity_mps() => velocity_mps
                 }},
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

            %{
              Relposned.relPosHeading() => rel_pos_heading_deg,
              Relposned.iTOW() => itow_ms,
              Relposned.relPosLength() => rel_pos_length_cm,
              Relposned.relPosHPLength() => rel_pos_hp_length_mm,
              Relposned.flags() => flags
            } = values

            # Logger.debug("RELPOSNED  #{inspect(values)}")
            rel_distance_m = rel_pos_length_cm * 0.01 + rel_pos_hp_length_mm * 0.001
            # Logger.debug("flags/dist: #{values.flags}/#{rel_distance_m}")

            # Logger.debug(
            #   "dist/expdist/thresh: #{rel_distance_m}/#{expected_gps_antenna_distance_m}/#{gps_antenna_distance_error_threshold_m}"
            # )

            if (flags &&& 261) == 261 and
                 abs(rel_distance_m - expected_gps_antenna_distance_m) <
                   gps_antenna_distance_error_threshold_m do
              rel_heading_rad = rel_pos_heading_deg |> ViaUtils.Math.deg2rad()
              # Logger.debug("gps rel hsg: #{ViaUtils.Format.eftb_deg(rel_heading_rad, 1)}")

              ViaUtils.Comms.cast_global_msg_to_group(
                __MODULE__,
                {Groups.gps_itow_relheading_val(),
                 %{SVN.itow_s() => itow_ms * 0.001, SVN.yaw_rad() => rel_heading_rad}},
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
