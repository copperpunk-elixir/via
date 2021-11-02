defmodule Uart.Companion do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Ubx.ClassDefs
  require ViaUtils.Ubx.AccelGyro.DtAccelGyro, as: DtAccelGyro
  require ViaUtils.Ubx.VehicleCmds.BodyrateThrustCmd, as: BodyrateThrustCmd
  require ViaUtils.Ubx.VehicleCmds.ActuatorCmdDirect, as: ActuatorCmdDirect
  require ViaUtils.Ubx.VehicleCmds.BodyrateActuatorOutput, as: BodyrateActuatorOutput
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaUtils.Shared.GoalNames, as: SGN
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @clear_is_value_current_callback :clear_is_value_current_callback_comp
  @imu :imu
  @direct_actuator_output :direct_actuator_output
  @bodyrate_actuator_loop :bodyrate_actuator_loop
  @any_pcl_actuator_loop :any_pcl_actuator_loop

  @spec start_link(keyword) :: {:ok, any}
  def start_link(config) do
    {:ok, pid} = ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config)
    Logger.debug("Start Uart.Companion at #{inspect(pid)}")
    {:ok, pid}
  end

  @impl GenServer
  def init(config) do
    controller_config = Keyword.fetch!(config, :controllers)

    %{bodyrate: bodyrate_channels, any_pcl: any_pcl_channels} =
      Keyword.fetch!(config, :channel_names)

    state = %{
      uart_ref: nil,
      ubx: UbxInterpreter.new(),
      pid_controllers: %{
        rollrate_aileron:
          ViaControllers.Pid.new(Keyword.fetch!(controller_config, :rollrate_aileron)),
        pitchrate_elevator:
          ViaControllers.Pid.new(Keyword.fetch!(controller_config, :pitchrate_elevator)),
        yawrate_rudder: ViaControllers.Pid.new(Keyword.fetch!(controller_config, :yawrate_rudder))
      },
      bodyrate_commands: %{},
      any_pcl_actuator_output: %{},
      bodyrate_actuator_output: %{},
      direct_actuator_output: %{},
      airspeed_mps: 0,
      is_value_current: %{
        @imu => false,
        @direct_actuator_output => false
      },
      imu_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @imu},
          2 *
            Keyword.get(
              config,
              :expected_imu_receive_interval_ms,
              LoopIntervals.imu_receive_max_ms()
            )
        ),
      direct_actuator_output_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @direct_actuator_output},
          2 * LoopIntervals.remote_pilot_goals_publish_ms()
        ),
      channel_names_direct: Map.merge(bodyrate_channels, any_pcl_channels),
      channel_names_any_pcl: any_pcl_channels,
      ubx_write_function: nil
    }

    ViaUtils.Comms.start_operator(__MODULE__)

    uart_port = Keyword.fetch!(config, :uart_port)
    Logger.info("Uart.Companion uart port: #{inspect(uart_port)}")

    ubx_write_function =
      if uart_port == "virtual" do
        Logger.debug("#{__MODULE__} virtual UART port")
        ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_dt_accel_gyro())

        ViaUtils.Process.start_loop(
          self(),
          LoopIntervals.bodyrate_actuator_publish_ms(),
          @bodyrate_actuator_loop
        )

        virtual_ubx_write()
      else
        port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
        GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
        real_ubx_write()
      end

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.any_pcl_actuator_publish_ms(),
      @any_pcl_actuator_loop
    )

    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_bodyrate_commands(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_direct_actuator_output(), self())
    ViaUtils.Comms.join_group(__MODULE__, Groups.commands_for_any_pilot_control_level())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity())

    Logger.debug("Uart.Companion.Operator #{uart_port} setup complete!")
    {:ok, %{state | ubx_write_function: ubx_write_function}}
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
  def handle_cast({Groups.controller_bodyrate_commands(), bodyrate_commands}, state) do
    Logger.debug("comp rx body commands: #{ViaUtils.Format.eftb_map(bodyrate_commands, 3)}")

    ubx_message =
      UbxInterpreter.construct_message_from_map(
        ViaUtils.Ubx.ClassDefs.vehicle_cmds(),
        BodyrateThrustCmd.id(),
        BodyrateThrustCmd.bytes(),
        BodyrateThrustCmd.multipliers(),
        BodyrateThrustCmd.keys(),
        bodyrate_commands
      )

    %{uart_ref: uart_ref} = state

    unless is_nil(uart_ref) do
      Circuits.UART.write(uart_ref, ubx_message)
    end

    {:noreply, %{state | bodyrate_commands: bodyrate_commands}}
  end

  @impl GenServer
  def handle_cast({Groups.commands_for_any_pilot_control_level(), any_pcl_commands}, state) do
    # Logger.debug("comp rx any_pcl_cmds: #{ViaUtils.Format.eftb_map(any_pcl_commands, 3)}")
    {:noreply, %{state | any_pcl_actuator_output: any_pcl_commands}}
  end

  @impl GenServer
  def handle_cast({Groups.controller_direct_actuator_output(), direct_actuator_output}, state) do
    # Logger.debug("comp rx ovrd_cmds: #{ViaUtils.Format.eftb_map(direct_actuator_output, 3)}")

    %{
      is_value_current: is_value_current,
      channel_names_direct: channel_names_direct,
      uart_ref: uart_ref,
      direct_actuator_output_watchdog: direct_actuator_output_watchdog
    } = state

    ubx_message = create_actuator_message(direct_actuator_output, channel_names_direct)

    if is_nil(uart_ref) do
      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {:circuits_uart, 0, ubx_message},
        self(),
        Groups.virtual_uart_actuator_output()
      )
    else
      Circuits.UART.write(uart_ref, ubx_message)
    end

    # Logger.debug("ubx: #{ubx_message}")

    direct_actuator_output_watchdog = Watchdog.reset(direct_actuator_output_watchdog)
    is_value_current = Map.put(is_value_current, @direct_actuator_output, true)

    {:noreply,
     %{
       state
       | is_value_current: is_value_current,
         direct_actuator_output_watchdog: direct_actuator_output_watchdog
     }}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_position_velocity(), _position, velocity}, state) do
    # Logger.debug("Comp rx vel: #{ViaUtils.Format.eftb_map(velocity, 1)}")
    %{SVN.airspeed_mps() => airspeed_mps} = velocity
    {:noreply, %{state | airspeed_mps: airspeed_mps}}
  end

  @impl GenServer
  def handle_cast({:send_message, message}, state) do
    Circuits.UART.write(state.uart_ref, message)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("rx'd data: #{inspect(data)}")
    state = check_for_new_messages_and_process(:binary.bin_to_list(data), state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_is_value_current_callback, key}, state) do
    Logger.warn(
      "#{inspect(__MODULE__)} clear #{inspect(key)}: #{inspect(get_in(state, [:is_value_current, key]))}"
    )

    state = put_in(state, [:is_value_current, key], false)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@bodyrate_actuator_loop, state) do
    %{
      is_value_current: is_value_current,
      bodyrate_actuator_output: bodyrate_actuator_output,
      uart_ref: uart_ref,
      ubx_write_function: ubx_write_function
    } = state
      Logger.warn("bodyrate act out: #{ViaUtils.Format.eftb_map(bodyrate_actuator_output, 3)}")
    unless is_value_current.direct_actuator_output or Enum.empty?(bodyrate_actuator_output) do
      # Logger.warn("comp act out: #{ViaUtils.Format.eftb_map(actuator_output, 3)}")

      ubx_message =
        UbxInterpreter.construct_message_from_map(
          ViaUtils.Ubx.ClassDefs.vehicle_cmds(),
          BodyrateActuatorOutput.id(),
          BodyrateActuatorOutput.bytes(),
          BodyrateActuatorOutput.multipliers(),
          BodyrateActuatorOutput.keys(),
          bodyrate_actuator_output
        )

      ubx_write_function.(ubx_message, uart_ref)
      # if is_nil(uart_ref) do
      #   ViaUtils.Comms.send_local_msg_to_group(
      #     __MODULE__,
      #     {:circuits_uart, 0, ubx_message},
      #     self(),
      #     Groups.virtual_uart_actuator_output()
      #   )
      # else
      #   Circuits.UART.write(uart_ref, ubx_message)
      # end
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@any_pcl_actuator_loop, state) do
    %{
      is_value_current: is_value_current,
      any_pcl_actuator_output: any_pcl_actuator_output,
      channel_names_any_pcl: channel_names_any_pcl,
      uart_ref: uart_ref,
      ubx_write_function: ubx_write_function
    } = state

    unless is_value_current.direct_actuator_output or Enum.empty?(any_pcl_actuator_output) do
      # Logger.warn("comp act out: #{ViaUtils.Format.eftb_map(actuator_output, 3)}")
      ubx_message = create_actuator_message(any_pcl_actuator_output, channel_names_any_pcl)
      ubx_write_function.(ubx_message, uart_ref)
      # if is_nil(uart_ref) do
      #   ViaUtils.Comms.send_local_msg_to_group(
      #     __MODULE__,
      #     {:circuits_uart, 0, ubx_message},
      #     self(),
      #     Groups.virtual_uart_actuator_output()
      #   )
      # else
      #   Circuits.UART.write(uart_ref, ubx_message)
      # end
    end

    {:noreply, state}
  end

  @spec check_for_new_messages_and_process(list(), map()) :: map()
  def check_for_new_messages_and_process(data, state) do
    %{ubx: ubx} = state
    {ubx, payload} = UbxInterpreter.check_for_new_message(ubx, data)

    if Enum.empty?(payload) do
      state
    else
      %{msg_class: msg_class, msg_id: msg_id} = ubx
      # Logger.debug("msg class/id: #{msg_class}/#{msg_id}")
      state =
        case msg_class do
          ViaUtils.Ubx.ClassDefs.accel_gyro() ->
            case msg_id do
              DtAccelGyro.id() ->
                values =
                  UbxInterpreter.deconstruct_message_to_map(
                    DtAccelGyro.bytes(),
                    DtAccelGyro.multipliers(),
                    DtAccelGyro.keys(),
                    payload
                  )

                # Logger.debug("dt/accel/gyro values: #{inspect([dt, ax, ay, az, gx, gy, gz])}")
                # Logger.debug("send dt/accel/gyro values: #{ViaUtils.Format.eftb_map(values, 3)}")

                ViaUtils.Comms.cast_local_msg_to_group(
                  __MODULE__,
                  {Groups.dt_accel_gyro_val(), values},
                  self()
                )

                state = calculate_bodyrate_actuator_output(values, state)

                %{state | ubx: UbxInterpreter.clear(ubx)}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                state
            end

          ViaUtils.Ubx.ClassDefs.vehicle_cmds() ->
            case msg_id do
              BodyrateThrustCmd.id() ->
                TestHelper.Companion.Utils.display_bodyrate_thrust_cmd(payload)
            end

            %{state | ubx: UbxInterpreter.clear(ubx)}

          _other ->
            Logger.warn("Bad message class: #{msg_class}")
            state
        end

      check_for_new_messages_and_process([], state)
    end
  end

  @spec create_actuator_message(map(), map()) :: binary()
  def create_actuator_message(actuator_output_map, channel_names) do
    {channel_payload_bytes, channel_payload_values} =
      ActuatorCmdDirect.Utils.get_payload_bytes_and_values(actuator_output_map, channel_names)

    # Logger.debug("bytes/values: #{inspect(channel_payload_bytes)}/#{inspect(channel_payload_values)}")
    UbxInterpreter.construct_message_from_list(
      ActuatorCmdDirect.class(),
      ActuatorCmdDirect.id(),
      channel_payload_bytes,
      channel_payload_values
    )
  end

  def calculate_bodyrate_actuator_output(dt_accel_gyro_values, state) do
    %{
      is_value_current: is_value_current,
      imu_watchdog: imu_watchdog,
      pid_controllers: pid_controllers,
      airspeed_mps: airspeed_mps,
      bodyrate_commands: bodyrate_commands,
      bodyrate_actuator_output: bodyrate_actuator_output_prev
    } = state

    # Logger.debug("comp is_val_cur: #{inspect(is_value_current)}")

    %{@direct_actuator_output => is_current_direct_actuator_output, @imu => is_current_imu} =
      is_value_current

    # Logger.debug("reset imu watch")
    imu_watchdog = Watchdog.reset(imu_watchdog)

    {pid_controllers, bodyrate_actuator_output} =
      cond do
        is_current_direct_actuator_output ->
          {reset_all_pid_integrators(pid_controllers), %{}}

        is_current_imu ->
          Logger.debug("br cmds: #{ViaUtils.Format.eftb_map(bodyrate_commands, 3)}")

          if !Enum.empty?(bodyrate_commands) do
            {pid_controllers, controller_output} =
              update_aileron_elevator_rudder_controllers(
                pid_controllers,
                bodyrate_commands,
                dt_accel_gyro_values,
                airspeed_mps
              )

            bodyrate_actuator_output =
              Map.merge(
                controller_output,
                Map.take(bodyrate_commands, [SGN.throttle_scaled()])
              )

            Logger.debug("ctrl out: #{ViaUtils.Format.eftb_map(bodyrate_actuator_output, 3)}")
            {pid_controllers, bodyrate_actuator_output}
          else
            {reset_all_pid_integrators(pid_controllers), bodyrate_actuator_output_prev}
          end

        true ->
          {reset_all_pid_integrators(pid_controllers), bodyrate_actuator_output_prev}
      end

    # elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{Estimation.Imu.Utils.rpy_to_string(ins_kf.imu, 2)}")
    is_value_current = Map.put(is_value_current, @imu, true)

    %{
      state
      | is_value_current: is_value_current,
        imu_watchdog: imu_watchdog,
        pid_controllers: pid_controllers,
        bodyrate_actuator_output: bodyrate_actuator_output
    }
  end

  @spec update_aileron_elevator_rudder_controllers(map(), map(), map(), number()) :: tuple()
  def update_aileron_elevator_rudder_controllers(
        controllers,
        bodyrate_commands,
        dt_accel_gyro_vals,
        airspeed_mps
      ) do
    %{
      rollrate_aileron: ctrl_rr_ail,
      pitchrate_elevator: ctrl_pr_elev,
      yawrate_rudder: ctrl_yr_rud
    } = controllers

    %{
      SGN.rollrate_rps() => cmd_rollrate_rps,
      SGN.pitchrate_rps() => cmd_pitchrate_rps,
      SGN.yawrate_rps() => cmd_yawrate_rps
    } = bodyrate_commands

    %{
      SVN.gyro_x_rps() => gx_rps,
      SVN.gyro_y_rps() => gy_rps,
      SVN.gyro_z_rps() => gz_rps,
      SVN.dt_s() => dt_s
    } = dt_accel_gyro_vals

    {aileron_controller, aileron_output} =
      ViaControllers.Pid.update(
        ctrl_rr_ail,
        cmd_rollrate_rps,
        gx_rps,
        airspeed_mps,
        dt_s
      )

    {elevator_controller, elevator_output} =
      ViaControllers.Pid.update(
        ctrl_pr_elev,
        cmd_pitchrate_rps,
        gy_rps,
        airspeed_mps,
        dt_s
      )

    # Logger.info("pr cmd/val/out: #{ViaUtils.Format.eftb(bodyrate_commands.pitchrate_rps,3)}/#{ViaUtils.Format.eftb(dt_accel_gyro_vals.gy_rps,3)}/#{ViaUtils.Format.eftb(elevator_output,3)}")
    {rudder_controller, rudder_output} =
      ViaControllers.Pid.update(
        ctrl_yr_rud,
        cmd_yawrate_rps,
        gz_rps,
        airspeed_mps,
        dt_s
      )

    {%{
       rollrate_aileron: aileron_controller,
       pitchrate_elevator: elevator_controller,
       yawrate_rudder: rudder_controller
     },
     %{
       aileron_scaled: aileron_output,
       elevator_scaled: elevator_output,
       rudder_scaled: rudder_output
     }}
  end

  @spec reset_all_pid_integrators(map()) :: map()
  def reset_all_pid_integrators(pid_controllers) do
    Enum.reduce(pid_controllers, %{}, fn {controller_name, controller}, acc ->
      Map.put(acc, controller_name, ViaControllers.Pid.reset_integrator(controller))
    end)
  end

  @spec send_message(binary()) :: atom()
  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

  @spec real_ubx_write() :: function()
  def real_ubx_write() do
    fn ubx_message, uart_ref ->
      Circuits.UART.write(uart_ref, ubx_message)
    end
  end

  @spec virtual_ubx_write() :: function()
  def virtual_ubx_write() do
    fn ubx_message, _ ->
      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {:circuits_uart, 0, ubx_message},
        self(),
        Groups.virtual_uart_actuator_output()
      )
    end
  end
end
