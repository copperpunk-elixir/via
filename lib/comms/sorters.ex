defmodule Comms.Sorters do
  require Comms.Groups, as: Groups
  defmacro goals, do: :goals
  def goals_sorter_for_pilot_control_level(pcl), do: {Groups.goals_sorter(), pcl}
  defmacro pilot_control_level, do: :pilot_control_level_sorter
end
