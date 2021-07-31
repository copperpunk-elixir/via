defmodule Command.ActuatorNames do
  defmacro aileron, do: :aileron_scaled
  defmacro elevator, do: :elevator_scaled
  defmacro rudder, do: :rudder_scaled
  defmacro throttle, do: :throttle_scaled
  defmacro flaps, do: :flaps_scaled
  defmacro gear, do: :gear_scaled
  defmacro multiplexor, do: :mux_scaled
  defmacro aux1, do: :aux1_scaled
  defmacro process_actuators, do: :process_actuators
end
