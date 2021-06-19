defmodule Comms.Sorters do
  require Comms.Groups, as: Groups
  defmacro goals, do: :goals
  defmacro pilot_control_level, do: :pilot_control_level_sorter
end
