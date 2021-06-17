defmodule Comms.Groups do

  defmacro autopilot_control_mode, do: :autopilot_control_mode
  defmacro dt_accel_gyro_val(), do: :dt_accel_gyro_val
  defmacro estimation_attitude, do: {:estimation_values, :attitude}

  defmacro estimation_position_speed_course_airspeed,
    do: {:estimation_values, :pos_gndspd_crs_airspd}

  defmacro gps_itow_position_velocity, do: :gps_pos_vel
  defmacro gps_itow_relheading, do: :gps_relhdg

  defmacro pilot_control_level, do: :pilot_control_level
  defmacro command_channels_failsafe, do: :command_channels_failsafe
  defmacro speed_course_altitude_sideslip_cmd, do: :scas_cmd
  defmacro speed_courserate_altituderate_sideslip_cmd, do: :s_cdot_adot_s_cmd
  defmacro roll_pitch_yawrate_throttle_cmd, do: :rp_ydot_t_cmd
  defmacro rollrate_pitchrate_yawrate_throttle_cmd, do: :rdot_pdot_y_dot_t_cmd
end
