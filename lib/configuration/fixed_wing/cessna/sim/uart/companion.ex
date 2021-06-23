defmodule Configuration.FixedWing.Cessna.Sim.Uart.Companion do
  require Logger
  require ViaUtils.Constants, as: VC
  require Command.ActuatorNames, as: Act

  @spec module_key_and_config(binary()) :: tuple()
  def module_key_and_config(uart_port) do
    {
      :Companion,
      [
        # usually Pico
        uart_port: uart_port,
        port_options: [speed: 115_200],
        accel_counts_to_mpss: VC.gravity() / 8192,
        gyro_counts_to_rps: VC.deg2rad() / 16.4,
        actuator_channels: %{
          Act.aileron() => 0,
          Act.elevator() => 1,
          Act.throttle() => 2,
          Act.rudder() => 3,
          Act.flaps() => 4,
          Act.gear() => 5
        }
      ]
    }
  end
end
