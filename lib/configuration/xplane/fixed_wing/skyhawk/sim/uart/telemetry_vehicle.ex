defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Uart.TelemetryVehicle do
  def config() do
    [
      publish_messages_frequency_max_hz: 50,
      vehicle_id: Configuration.Utils.get_vehicle_id(__MODULE__)
    ]
  end
end
