defmodule Uart.Companion do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Ubx.ClassDefs
  require Ubx.AccelGyro.DtAccelGyro, as: DtAccelGyro
  require Ubx.VehicleCmds.BodyrateThrustCmd, as: BodyrateThrustCmd
  require Ubx.VehicleCmds.ActuatorOverrideCmd_1_8, as: ActuatorOverrideCmd_1_8
  require Ubx.VehicleCmds.ActuatorOverrideCmd_9_16, as: ActuatorOverrideCmd_9_16

  @spec start_link(keyword) :: {:ok, any}
  def start_link(config) do
    Logger.debug("Start Uart.Companion")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_bodyrate_goals(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_override_commands(), self())

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      accel_counts_to_mpss: Keyword.fetch!(config, :accel_counts_to_mpss),
      gyro_counts_to_rps: Keyword.fetch!(config, :gyro_counts_to_rps),
      channels_config_1_8: Keyword.fetch!(config, :channels_1_8)
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
    Logger.debug("Uart.Companion.Operator #{uart_port} setup complete!")
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
  def handle_cast({Groups.controller_bodyrate_goals(), bodyrate_goals}, state) do
    Logger.debug("comp rx goals: #{ViaUtils.Format.eftb_map(bodyrate_goals, 3)}")

    ubx_message =
      UbxInterpreter.construct_message_from_map(
        Ubx.ClassDefs.vehicle_cmds(),
        BodyrateThrustCmd.id(),
        BodyrateThrustCmd.bytes(),
        BodyrateThrustCmd.multiplier(),
        BodyrateThrustCmd.keys(),
        bodyrate_goals
      )

    Circuits.UART.write(state.uart_ref, ubx_message)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({Groups.controller_override_commands(), override_commands}, state) do
    channels_config_1_8 = state.channels_config_1_8

    {channel_values_1_8, channel_values_9_16} =
      Map.split(override_commands, channels_config_1_8.keys)

    # Fill in missing values with default values, as defined by Companion config
    channel_values_1_8 = Map.merge(channels_config_1_8.default_values, channel_values_1_8)
    Logger.warn("ch 1-8: #{ViaUtils.Format.eftb_map(channel_values_1_8,3)}")

    ubx_message_1_8 =
      UbxInterpreter.construct_message_from_map(
        Ubx.ClassDefs.vehicle_cmds(),
        ActuatorOverrideCmd_1_8.id(),
        ActuatorOverrideCmd_1_8.bytes(),
        ActuatorOverrideCmd_1_8.multiplier(),
        channels_config_1_8.keys,
        channel_values_1_8
      )

    Circuits.UART.write(state.uart_ref, ubx_message_1_8)

    if !Enum.empty?(channel_values_9_16) do
      Logger.debug("More than 8 channels. Must send 9-16 message")

      ubx_message_9_16 =
        UbxInterpreter.construct_message_from_map(
          Ubx.ClassDefs.vehicle_cmds(),
          ActuatorOverrideCmd_9_16.id(),
          ActuatorOverrideCmd_9_16.bytes(),
          ActuatorOverrideCmd_9_16.multiplier(),
          ActuatorOverrideCmd_9_16.keys(),
          channel_values_9_16
        )

      Circuits.UART.write(state.uart_ref, ubx_message_9_16)
    end

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
      UbxInterpreter.check_for_new_messages_and_process(
        state.ubx,
        :binary.bin_to_list(data),
        &process_data_fn/3,
        []
      )

    {:noreply, %{state | ubx: ubx}}
  end

  @spec process_data_fn(integer(), integer(), list()) :: atom()
  def process_data_fn(msg_class, msg_id, payload) do
    # Logger.debug("Comp rx class/id: #{msg_class}/#{msg_id}")
    case msg_class do
      Ubx.ClassDefs.accel_gyro() ->
        case msg_id do
          DtAccelGyro.id() ->
            values =
              UbxInterpreter.deconstruct_message(
                DtAccelGyro.bytes(),
                DtAccelGyro.multipliers(),
                DtAccelGyro.keys(),
                payload
              )

            # Logger.debug("dt/accel/gyro values: #{inspect([dt, ax, ay, az, gx, gy, gz])}")

            # Logger.debug("dt/accel/gyro values: #{ViaUtils.Format.eftb_list(values, 3)}")
            ViaUtils.Comms.send_local_msg_to_group(
              __MODULE__,
              {Groups.dt_accel_gyro_val(), values},
              self()
            )

          _other ->
            Logger.warn("Bad message id: #{msg_id}")
        end

      Ubx.ClassDefs.vehicle_cmds() ->
        case msg_id do
          BodyrateThrustCmd.id() ->
            TestHelper.Companion.Utils.display_bodyrate_thrust_cmd(payload)

          ActuatorOverrideCmd_1_8.id() ->
            TestHelper.Companion.Utils.display_actuator_override_cmd_1_8(payload)
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
