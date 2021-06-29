defmodule Configuration.LoopIntervals do
  # ESTIMATION
  defmacro attitude_publish_ms, do: 20
  defmacro position_velocity_publish_ms, do: 20
  defmacro airspeed_receive_max_ms, do: 200
  defmacro gps_receive_max_ms, do: 200
  defmacro imu_receive_max_ms, do: 5
  defmacro rangefinder_receive_max_ms, do: 200

  # CONTROL
  defmacro controller_update_ms, do: 20

  # GOALS
  defmacro commander_goals_publish_ms, do: 20

  defmacro navigator_goals_publish_ms, do: 40
  defmacro remote_pilot_goals_publish_ms, do: 20

  # CLUSTER
  defmacro heartbeat_publish_ms, do: 100
end
