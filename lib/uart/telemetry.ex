defmodule Uart.Telemetry do
  use GenServer
  use Bitwise
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require Configuration.LoopIntervals, as: LoopIntervals

  @publish_telemetry_loop :publish_telemetry_loop
  def start_link(config) do
    Logger.debug("Start Uart.Telemetry with config: #{inspect(config)}")
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

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      values: values_placeholder,
      telemetry_msgs: telemetry_msgs
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    Logger.info("#{__MODULE__} uart port: #{inspect(uart_port)}")

    if uart_port == "virtual" do
      Logger.debug("#{__MODULE__} virtual UART port")
      ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_gps())
    else
      port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
      GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
    end

    # ViaUtils.Comms.join_group(__MODULE__, Groups.controller_bodyrate_commands(), self())
    # ViaUtils.Comms.join_group(__MODULE__, Groups.controller_direct_actuator_output(), self())
    # ViaUtils.Comms.join_group(__MODULE__, Groups.commands_for_any_pilot_control_level())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude_attrate_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.current_pcl_and_all_commands_val())

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.telemetry_publish_ms(),
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
    %{values: values, telemetry_msgs: telemetry_msgs, uart_ref: uart_ref} = state

    values = Map.put(values, SVN.time_since_boot_s(), :erlang.system_time(:millisecond))

    Enum.each(telemetry_msgs, fn msg_module ->
      # Logger.debug("msg type: #{msg_module}")
      keys = msg_module.get_keys()
      msg_values = Map.take(values, keys)

      ubx_message =
        UbxInterpreter.construct_message_from_map(
          msg_module.get_class(),
          msg_module.get_id(),
          msg_module.get_bytes(),
          msg_module.get_multipliers(),
          keys,
          msg_values
        )

      if is_nil(uart_ref) do
        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          {:circuits_uart, 0, ubx_message},
          self(),
          Groups.virtual_telemetry()
        )
      else
        Circuits.UART.write(uart_ref, ubx_message)
      end

      # Logger.debug("msg values: #{inspect(msg_values)}")
    end)

    # unless is_nil(attitude_rad) or is_nil(attrate_rps) do
    #   Logger.debug(
    #     "Telem att/attrate: #{ViaUtils.Format.eftb_map_deg(attitude_rad, 1)}/#{ViaUtils.Format.eftb_map_deg(attrate_rps, 1)}"
    #   )
    # end

    {:noreply, state}
  end

  @spec check_for_new_messages_and_process(list(), map()) :: map()
  def check_for_new_messages_and_process(data, state) do
    %{ubx: ubx} = state
    {ubx, payload} = UbxInterpreter.check_for_new_message(ubx, data)

    if Enum.empty?(payload) do
      state
    else
      # Logger.debug("payload: #{inspect(payload)}")
      check_for_new_messages_and_process([], %{state | ubx: UbxInterpreter.clear(ubx)})
    end
  end
end
