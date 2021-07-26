defmodule Simulation.Interface do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @clear_is_value_current_callback :clear_is_value_current_callback
  @imu :imu
  @override_commands :override_commands
  @actuator_loop :actuator_loop

  def start_link(config) do
    Logger.debug("Start Simulation.Interface GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    controller_config = Keyword.fetch!(config, :controllers)

    state = %{
      pid_controllers: %{
        rollrate_aileron:
          ViaControllers.Pid.new(Keyword.fetch!(controller_config, :rollrate_aileron)),
        pitchrate_elevator:
          ViaControllers.Pid.new(Keyword.fetch!(controller_config, :pitchrate_elevator)),
        yawrate_rudder: ViaControllers.Pid.new(Keyword.fetch!(controller_config, :yawrate_rudder))
      },
      bodyrate_goals: %{},
      override_commands: %{},
      airspeed_mps: 0,
      actuator_output: %{},
      is_value_current: %{
        imu: false,
        override_commands: false
      },
      imu_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @imu},
          2 * LoopIntervals.imu_receive_max_ms()
        ),
      override_commands_watchdog:
        Watchdog.new(
          {@clear_is_value_current_callback, @override_commands},
          2 * LoopIntervals.remote_pilot_goals_publish_ms()
        )
    }

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.dt_accel_gyro_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity())
    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_bodyrate_goals())
    ViaUtils.Comms.join_group(__MODULE__, Groups.controller_override_commands())

    ViaUtils.Process.start_loop(self(), LoopIntervals.actuator_output_ms(), @actuator_loop)
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.dt_accel_gyro_val(), values}, state) do
    # Logger.debug("Sim.Int rx dt_accel_gyro: #{ViaUtils.Format.eftb_map(values, 3)}")
    imu_watchdog = Watchdog.reset(state.imu_watchdog)
    is_value_current = state.is_value_current

    {pid_controllers, actuator_output} =
      cond do
        is_value_current.override_commands ->
          {reset_all_pid_integrators(state.pid_controllers), state.override_commands}

        is_value_current.imu ->
          bodyrate_goals = state.bodyrate_goals

          if !Enum.empty?(bodyrate_goals) do
            {pid_controllers, controller_output} =
              update_aileron_elevator_rudder_controllers(
                state.pid_controllers,
                bodyrate_goals,
                values,
                state.airspeed_mps
              )

            actuator_output =
              Map.merge(
                controller_output,
                Map.drop(bodyrate_goals, [:rollrate_rps, :pitchrate_rps, :yawrate_rps])
              )

            {pid_controllers, actuator_output}
          else
            {reset_all_pid_integrators(state.pid_controllers), state.actuator_output}
          end

        true ->
          {reset_all_pid_integrators(state.pid_controllers), state.actuator_output}
      end

    # elapsed_time = :erlang.monotonic_time(:microsecond) - state.start_time
    # Logger.debug("rpy: #{elapsed_time}: #{Estimation.Imu.Utils.rpy_to_string(ins_kf.imu, 2)}")
    is_value_current = Map.put(state.is_value_current, :imu, true)

    {:noreply,
     %{
       state
       | is_value_current: is_value_current,
         imu_watchdog: imu_watchdog,
         pid_controllers: pid_controllers,
         actuator_output: actuator_output
     }}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_position_velocity(), _position, velocity}, state) do
    # Logger.debug("Sim.Int rx vel: #{ViaUtils.Format.eftb_map(velocity, 1)}")
    {:noreply, %{state | airspeed_mps: velocity.airspeed_mps}}
  end

  @impl GenServer
  def handle_cast({Groups.controller_bodyrate_goals(), bodyrate_goals}, state) do
    # Need to calculate
    # Logger.debug("Sim.Int rx goals: #{ViaUtils.Format.eftb_map(bodyrate_goals, 3)}")

    {:noreply, %{state | bodyrate_goals: bodyrate_goals}}
  end

  @impl GenServer
  def handle_cast({Groups.controller_override_commands(), override_commands}, state) do
    # Logger.debug("Sim.Int rx ovrd: #{ViaUtils.Format.eftb_map(override_commands, 3)}")

    override_commands_watchdog = Watchdog.reset(state.override_commands_watchdog)
    is_value_current = Map.put(state.is_value_current, :override_commands, true)

    {:noreply,
     %{
       state
       | override_commands_watchdog: override_commands_watchdog,
         override_commands: override_commands,
         is_value_current: is_value_current
     }}
  end

  @impl GenServer
  def handle_info(@actuator_loop, state) do
    actuator_output = state.actuator_output
    # Logger.warn("sim int act out: #{ViaUtils.Format.eftb_map(actuator_output, 3)}")

    unless(Enum.empty?(actuator_output)) do
      send_actuator_output(actuator_output)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_is_value_current_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(get_in(state, [:is_value_current, key]))}")
    state = put_in(state, [:is_value_current, key], false)
    {:noreply, state}
  end

  @spec send_actuator_output(map()) :: atom()
  def send_actuator_output(actuator_output) do
    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.simulation_update_actuators(), actuator_output},
      self()
    )
  end

  @spec update_aileron_elevator_rudder_controllers(map(), map(), map(), number()) :: tuple()
  def update_aileron_elevator_rudder_controllers(
        controllers,
        bodyrate_goals,
        dt_accel_gyro_vals,
        airspeed_mps
      ) do
    dt_s = dt_accel_gyro_vals.dt_s

    {aileron_controller, aileron_output} =
      ViaControllers.Pid.update(
        controllers.rollrate_aileron,
        bodyrate_goals.rollrate_rps,
        dt_accel_gyro_vals.gx_rps,
        airspeed_mps,
        dt_s
      )

    {elevator_controller, elevator_output} =
      ViaControllers.Pid.update(
        controllers.pitchrate_elevator,
        bodyrate_goals.pitchrate_rps,
        dt_accel_gyro_vals.gy_rps,
        airspeed_mps,
        dt_s
      )

    # Logger.info("pr cmd/val/out: #{ViaUtils.Format.eftb(bodyrate_goals.pitchrate_rps,3)}/#{ViaUtils.Format.eftb(dt_accel_gyro_vals.gy_rps,3)}/#{ViaUtils.Format.eftb(elevator_output,3)}")
    {rudder_controller, rudder_output} =
      ViaControllers.Pid.update(
        controllers.yawrate_rudder,
        bodyrate_goals.yawrate_rps,
        dt_accel_gyro_vals.gz_rps,
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
end
