defmodule Uart.TelemetryGround do
  use GenServer
  use Bitwise
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaTelemetry.Ubx.MsgClasses, as: MsgClasses
  alias ViaTelemetry.Ubx.VehicleCmds, as: VehicleCmds
  alias ViaTelemetry.Ubx.VehicleState, as: VehicleState
  require VehicleCmds.AttitudeThrustCmd, as: AttitudeThrustCmd
  require VehicleCmds.BodyrateThrottleCmd, as: BodyrateThrottleCmd
  require VehicleCmds.ActuatorCmdDirect, as: ActuatorCmdDirect
  require VehicleCmds.SpeedCourseAltitudeSideslipCmd, as: SpeedCourseAltitudeSideslipCmd
  require VehicleCmds.SpeedCourserateAltrateSideslipCmd, as: SpeedCourserateAltrateSideslipCmd
  require VehicleCmds.ControllerActuatorOutput, as: ControllerActuatorOutput
  require VehicleState.AttitudeAttrateVal, as: AttitudeAttrateVal
  require VehicleState.PositionVelocityVal, as: PositionVelocityVal

  def start_link(config) do
    Logger.debug("Start #{__MODULE__} with config: #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.start_operator(__MODULE__)

    uart_port = Keyword.fetch!(config, :uart_port)
    Logger.info("#{__MODULE__} uart port: #{inspect(uart_port)}")

    ubx_write_function =
      if uart_port == "virtual" do
        Logger.debug("#{__MODULE__} virtual UART port")
        ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_telemetry_ground())
        ViaUtils.Uart.virtual_ubx_write(Groups.virtual_uart_telemetry_vehicle(), __MODULE__)
      else
        port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
        GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
        ViaUtils.Uart.real_ubx_write()
      end

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      ubx_write_function: ubx_write_function
    }

    ViaUtils.Comms.join_group(__MODULE__, Groups.telemetry_ground_send_message())
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
  def handle_cast({Groups.telemetry_ground_send_message(), message}, state) do
    %{ubx_write_function: ubx_write_function, uart_ref: uart_ref} = state
    ubx_write_function.(message, uart_ref)
    Logger.debug("#{__MODULE__} write message #{message}")
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("Telem rx'd data: #{inspect(data)}")
    state = check_for_new_messages_and_process(:binary.bin_to_list(data), state)

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
      %{msg_class: msg_class, msg_id: msg_id} = ubx
      # Logger.debug("#{__MODULE__} rx class/id: #{msg_class}/#{msg_id}")
      {bytes, multipliers, keys, group} =
        case msg_class do
          MsgClasses.vehicle_state() ->
            case msg_id do
              AttitudeAttrateVal.id() ->
                {AttitudeAttrateVal.bytes(), AttitudeAttrateVal.multipliers(),
                 AttitudeAttrateVal.keys(), Groups.ubx_attitude_attrate_val()}

              PositionVelocityVal.id() ->
                {PositionVelocityVal.bytes(), PositionVelocityVal.multipliers(),
                 PositionVelocityVal.keys(), Groups.ubx_position_velocity_val()}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                {nil, nil, nil, nil}
            end

          MsgClasses.vehicle_cmds() ->
            case msg_id do
              BodyrateThrottleCmd.id() ->
                {BodyrateThrottleCmd.bytes(), BodyrateThrottleCmd.multipliers(),
                 BodyrateThrottleCmd.keys(), Groups.ubx_bodyrate_throttle_cmd()}

              AttitudeThrustCmd.id() ->
                {AttitudeThrustCmd.bytes(), AttitudeThrustCmd.multipliers(),
                 AttitudeThrustCmd.keys(), Groups.ubx_attitude_thrust_cmd()}

              SpeedCourseAltitudeSideslipCmd.id() ->
                {SpeedCourseAltitudeSideslipCmd.bytes(),
                 SpeedCourseAltitudeSideslipCmd.multipliers(),
                 SpeedCourseAltitudeSideslipCmd.keys(),
                 Groups.ubx_speed_course_altitude_sideslip_cmd()}

              SpeedCourserateAltrateSideslipCmd.id() ->
                {SpeedCourserateAltrateSideslipCmd.bytes(),
                 SpeedCourserateAltrateSideslipCmd.multipliers(),
                 SpeedCourserateAltrateSideslipCmd.keys(),
                 Groups.ubx_speed_courserate_altrate_sideslip_cmd()}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                {nil, nil, nil, nil}
            end

          # case msg_id do
          # end

          _other ->
            Logger.warn("Bad message class: #{msg_class}")
        end

      unless is_nil(bytes) do
        values =
          UbxInterpreter.deconstruct_message_to_map(
            bytes,
            multipliers,
            keys,
            payload
          )

        # Logger.debug("#{__MODULE__} group/vals: #{inspect(group)}/#{inspect(values)}")

        ViaUtils.Comms.cast_global_msg_to_group(
          __MODULE__,
          {group, values},
          self()
        )
      end

      check_for_new_messages_and_process([], %{state | ubx: UbxInterpreter.clear(ubx)})
    end
  end
end
