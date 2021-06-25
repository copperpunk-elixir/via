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
        channels_1_8: %{
          keys: [
            Act.aileron(),
            Act.elevator(),
            Act.throttle(),
            Act.rudder(),
            Act.flaps(),
            Act.gear(),
            Act.aux1(),
            Act.multiplexor()
          ],
          default_values: %{
            Act.aileron() => 0,
            Act.elevator() => 0,
            Act.throttle() => -1.0,
            Act.rudder() => 0,
            Act.flaps() => -1.0,
            Act.gear() => -1.0,
            Act.aux1() => -1.0,
            Act.multiplexor() => -1.0
          }
        }
      ]
    }
  end
end
