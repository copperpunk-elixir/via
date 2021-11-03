defmodule Configuration.LoopIntervals do
  # COMPANION
  defmacro bodyrate_actuator_publish_ms, do: 20
  defmacro any_pcl_actuator_publish_ms, do: 200

 # CONTROL
  defmacro controller_update_ms, do: 20

  # ESTIMATION
  defmacro attitude_publish_ms, do: 20
  defmacro position_velocity_publish_ms, do: 20
  defmacro airspeed_receive_max_ms, do: 200
  defmacro gps_receive_max_ms, do: 200
  defmacro imu_receive_max_ms, do: 5
  defmacro rangefinder_receive_max_ms, do: 200



  # GOALS
  defmacro commands_publish_ms, do: 20

  defmacro navigator_goals_publish_ms, do: 40
  defmacro remote_pilot_goals_publish_ms, do: 40

  # CLUSTER
  defmacro heartbeat_publish_ms, do: 100


  # JOYSTICK
  defmacro joystick_channels_publish_ms, do: 20

  # KEYBOARD
  defmacro keyboard_channels_publish_ms, do: 20
end
