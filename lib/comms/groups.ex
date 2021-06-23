defmodule Comms.Groups do

  defmacro autopilot_control_mode, do: :autopilot_control_mode
  defmacro dt_accel_gyro_val(), do: :dt_accel_gyro_val
  defmacro estimation_attitude, do: {:estimation_values, :attitude}

  defmacro estimation_position_groundalt_groundspeed_verticalvelocity_course_airspeed,
    do: {:estimation_values, :pos_gndalt_gndspd_vv_crs_airspd}

  defmacro gps_itow_position_velocity, do: :gps_pos_vel
  defmacro gps_itow_relheading, do: :gps_relhdg

  defmacro pilot_control_level, do: :pilot_control_level
  defmacro command_channels_failsafe, do: :command_channels_failsafe
  defmacro speed_course_altitude_sideslip_cmd, do: :scas_cmd
  defmacro speed_courserate_altituderate_sideslip_cmd, do: :s_cdot_adot_s_cmd
  defmacro roll_pitch_yawrate_throttle_cmd, do: :rp_ydot_t_cmd
  defmacro rollrate_pitchrate_yawrate_throttle_cmd, do: :rdot_pdot_y_dot_t_cmd

  defmacro commander_goals, do: :commander_goals
  defmacro pilot_control_level_and_goals_sorter, do: :pcl_and_goals_sorter
  defmacro message_sorter_value, do: :message_sorter_value
  defmacro remote_pilot_goals_override, do: :remote_pilot_goals_override
end
