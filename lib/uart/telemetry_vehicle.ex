defmodule Uart.TelemetryVehicle do
  use GenServer
  use Bitwise
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaTelemetry.Ubx.MsgClasses, as: MsgClasses
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaTelemetry.Ubx.Actions.SubscribeToMsg, as: SubscribeToMsg
  alias ViaUtils.DiscreteLooper.List, as: DL

  @publish_telemetry_loop :publish_telemetry_loop
  def start_link(config) do
    Logger.debug("Start #{__MODULE__} with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)

    telemetry_msgs = Keyword.get(config, :telemetry_msgs, [])

    values_placeholder =
      Enum.reduce(telemetry_msgs, %{}, fn msg_module, acc ->
        keys_and_values =
          Enum.reduce(apply(msg_module, :get_keys, []), %{}, fn key, acc2 ->
            Map.put(acc2, key, 0)
          end)

        Map.merge(acc, keys_and_values)
      end)

    Logger.debug("#{__MODULE__} values_placeholder: #{inspect(values_placeholder)}")

    uart_port = Keyword.fetch!(config, :uart_port)
    Logger.info("#{__MODULE__} uart port: #{inspect(uart_port)}")

    ubx_write_function =
      if uart_port == "virtual" do
        Logger.debug("#{__MODULE__} virtual UART port")
        ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_telemetry_vehicle())
        ViaUtils.Uart.virtual_ubx_write(Groups.virtual_uart_telemetry_ground(), __MODULE__)
      else
        port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
        GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
        ViaUtils.Uart.real_ubx_write()
      end

    publish_messages_interval_ms =
      round(1000 / Keyword.fetch!(config, :publish_messages_frequency_max_hz))

    if rem(1000, publish_messages_interval_ms) != 0,
      do: raise("#{__MODULE__} publish messages interval must be whole number")

    publish_messages_looper = DL.new(__MODULE__, publish_messages_interval_ms)

    state = %{
      uart_ref: nil,
      vehicle_id: Keyword.fetch!(config, :vehicle_id),
      ubx: UbxInterpreter.new(),
      values: values_placeholder,
      telemetry_msgs: telemetry_msgs,
      ubx_write_function: ubx_write_function,
      publish_messages_looper: publish_messages_looper
    }

    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude_attrate_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.current_pcl_and_all_commands_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.current_pcl_and_all_commands_val())

    ViaUtils.Process.start_loop(
      self(),
      publish_messages_interval_ms,
      @publish_telemetry_loop
    )

    Logger.debug("#{__MODULE__} #{uart_port} setup complete!")
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.error("#{__MODULE__} terminate: #{inspect(reason)}")

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
  def handle_cast({{Groups.val_prefix(), _value_type}, values}, state) do
    # Logger.debug("Telem rx values (#{inspect(value_type)}): #{inspect(values)}")
    values = Map.merge(state.values, values)

    {:noreply, %{state | values: values}}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("Telem rx'd data: #{inspect(data)}")
    state = check_for_new_messages_and_process(:binary.bin_to_list(data), state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@publish_telemetry_loop, state) do
    %{
      values: values,
      # telemetry_msgs: telemetry_msgs,
      uart_ref: uart_ref,
      ubx_write_function: ubx_write_function,
      publish_messages_looper: publish_messages_looper
    } = state

    publish_messages_looper = DL.step(publish_messages_looper)
    looper_members = DL.get_members_now(publish_messages_looper)
    # Logger.debug("looper: #{inspect(publish_messages_looper)}")
    # Logger.debug("send to modules: #{inspect(looper_members)}")

    Enum.each(looper_members, fn msg_module ->
      # Logger.debug("msg type: #{msg_module}")
      keys = msg_module.get_keys()

      msg_values =
        ViaTelemetry.Ubx.Utils.add_time(values)
        |> Map.take(keys)

      # Logger.debug("mod/keys/vals: #{msg_module}/#{inspect(keys)}/#{inspect(msg_values)}")

      ubx_message =
        UbxInterpreter.construct_message_from_map(
          msg_module.get_class(),
          msg_module.get_id(),
          msg_module.get_bytes(),
          msg_module.get_multipliers(),
          keys,
          msg_values
        )

      ubx_write_function.(ubx_message, uart_ref)
    end)

    {:noreply, %{state | publish_messages_looper: publish_messages_looper}}
  end

  @spec check_for_new_messages_and_process(list(), map()) :: map()
  def check_for_new_messages_and_process(data, state) do
    %{ubx: ubx} = state
    {ubx, payload} = UbxInterpreter.check_for_new_message(ubx, data)

    if Enum.empty?(payload) do
      state
    else
      # Logger.debug("payload: #{inspect(payload)}")
      %{msg_class: msg_class, msg_id: msg_id} = ubx
      # Logger.debug("rx class/id# #{msg_class}/#{msg_id}")

      state =
        case msg_class do
          # We will support vehicle_cmds through UBX messages at a later time
          # MsgClasses.vehicle_cmds() ->
          #   case msg_id do
          #     BodyrateThrottleCmd.id() ->
          #       {BodyrateThrottleCmd.bytes(), BodyrateThrottleCmd.multipliers(),
          #        BodyrateThrottleCmd.keys(), Groups.bodyrate_throttle_cmd()}

          #     AttitudeThrustCmd.id() ->
          #       {AttitudeThrustCmd.bytes(), AttitudeThrustCmd.multipliers(),
          #        AttitudeThrustCmd.keys(), Groups.attitude_thrust_cmd()}

          #     SpeedCourseAltitudeSideslipCmd.id() ->
          #       {SpeedCourseAltitudeSideslipCmd.bytes(),
          #        SpeedCourseAltitudeSideslipCmd.multipliers(),
          #        SpeedCourseAltitudeSideslipCmd.keys(),
          #        Groups.speed_course_altitude_sideslip_cmd()}

          #     SpeedCourserateAltrateSideslipCmd.id() ->
          #       {SpeedCourserateAltrateSideslipCmd.bytes(),
          #        SpeedCourserateAltrateSideslipCmd.multipliers(),
          #        SpeedCourserateAltrateSideslipCmd.keys(),
          #        Groups.speed_courserate_altrate_sideslip_cmd()}

          #     _other ->
          #       Logger.warn("Bad message id: #{msg_id}")
          #       {nil, nil, nil, nil}
          #   end

          MsgClasses.actions() ->
            case msg_id do
              SubscribeToMsg.id() ->
                Logger.debug("Telem veh rx'd sub to msg")

                values =
                  UbxInterpreter.deconstruct_message_to_map(
                    SubscribeToMsg.bytes(),
                    SubscribeToMsg.multipliers(),
                    SubscribeToMsg.keys(),
                    payload
                  )

                %{
                  SVN.message_class() => msg_class,
                  SVN.message_id() => msg_id,
                  SVN.message_frequency_hz() => msg_freq_hz
                } = values

                interval_ms = round(1000 / msg_freq_hz)
                msg_module = ViaTelemetry.Ubx.Utils.get_module_for_class_and_id(msg_class, msg_id)

                publish_messages_looper =
                  DL.add_member_to_looper(
                    state.publish_messages_looper,
                    msg_module,
                    interval_ms
                  )

                # Logger.debug("Looper subs: #{inspect(publish_messages_looper.members)}")
                %{state | publish_messages_looper: publish_messages_looper}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                state
            end

          _other ->
            Logger.warn("Bad message class: #{msg_class}")
            state
        end

      check_for_new_messages_and_process([], %{state | ubx: UbxInterpreter.clear(ubx)})
    end
  end
end
