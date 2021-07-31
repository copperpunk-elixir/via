defmodule Comms.Groups do
  defmacro airspeed_val, do: :airspeed_val
  defmacro all_levels_commands, do: :all_levels_commands
  defmacro autopilot_control_mode, do: :autopilot_control_mode
  defmacro controller_bodyrate_commands, do: :controller_bodyrate_commands
  defmacro controller_override_commands, do: :controller_override_commands
  defmacro command_channels, do: :command_channels
  defmacro commands, do: :commands
  defmacro downward_tof_distance_val, do: :downward_tof_distance_val
  defmacro dt_accel_gyro_val, do: :dt_accel_gyro_val
  defmacro estimation_attitude, do: {:estimation_values, :attitude}

  defmacro estimation_position_velocity,
    do: {:estimation_values, :position_velocity}

  defmacro gps_itow_position_velocity_val, do: :gps_pos_vel_val
  defmacro gps_itow_relheading_val, do: :gps_relhdg_val

  defmacro independent_goals, do: :independent_goals
  defmacro message_sorter_value, do: :message_sorter_value
  defmacro remote_pilot_override_commands, do: :remote_pilot_override_commands
  defmacro roll_pitch_yawrate_thrust_cmd, do: :rp_ydot_t_cmd
  defmacro rollrate_pitchrate_yawrate_thrust_cmd, do: :rdot_pdot_y_dot_t_cmd
  defmacro simulation_update_actuators, do: :simulation_update_actuators
  defmacro sorter_pilot_control_level_and_goals, do: :sorter_pcl_and_goals
  defmacro speed_course_altitude_sideslip_cmd, do: :scas_cmd
  defmacro speed_courserate_altituderate_sideslip_cmd, do: :s_cdot_adot_s_cmd
end
