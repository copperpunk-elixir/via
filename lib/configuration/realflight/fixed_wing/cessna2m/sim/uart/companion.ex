defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Companion do
  require ViaUtils.Shared.ActuatorNames, as: Act

  def config() do
    [
      channels_1_8: %{
        Act.aileron() => 0,
        Act.elevator() => 1,
        Act.throttle() => 2,
        Act.rudder() => 3,
        Act.flaps() => 4,
        Act.gear() => 5
      },
      number_active_channels: 6
    ]
  end
end
