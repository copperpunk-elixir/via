defmodule Command.Actuators do
  defmacro aileron, do: :aileron
  defmacro elevator, do: :elevator
  defmacro rudder, do: :rudder
  defmacro throttle, do: :throttle
  defmacro flaps, do: :flaps
  defmacro gear, do: :gear
end
