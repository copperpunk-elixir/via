defmodule Comms.Sorters do
  defmacro heartbeat_node, do: {:hb, :node}
  defmacro pilot_control_level_and_goals, do: :pcl_and_goals
end
