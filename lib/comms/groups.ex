defmodule Comms.Groups do
  defmacro autopilot_control_mode, do: :autopilot_control_mode
  defmacro command_channels_failsafe, do: :command_channels_failsafe
  defmacro commander_goals, do: :commander_goals
  defmacro dt_accel_gyro_val(), do: :dt_accel_gyro_val
  defmacro estimation_attitude_dt, do: {:estimation_values, :attitude_dt}

  defmacro estimation_position_velocity_dt,
    do: {:estimation_values, :position_velocity_dt}

  defmacro gps_itow_position_velocity, do: :gps_pos_vel
  defmacro gps_itow_relheading, do: :gps_relhdg
  defmacro message_sorter_value, do: :message_sorter_value
  defmacro remote_pilot_override_commands, do: :remote_pilot_override_commands
  defmacro roll_pitch_yawrate_throttle_cmd, do: :rp_ydot_t_cmd
  defmacro rollrate_pitchrate_yawrate_throttle_cmd, do: :rdot_pdot_y_dot_t_cmd
  defmacro sorter_pilot_control_level_and_goals, do: :sorter_pcl_and_goals
  defmacro speed_course_altitude_sideslip_cmd, do: :scas_cmd
  defmacro speed_courserate_altituderate_sideslip_cmd, do: :s_cdot_adot_s_cmd
end
