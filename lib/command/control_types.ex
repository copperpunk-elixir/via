defmodule Command.ControlTypes do
  defmacro autopilot_control_mode_full_auto, do: 3
  defmacro autopilot_control_mode_controller_assist, do: 2
  defmacro autopilot_control_mode_disengaged, do: 1

  defmacro pilot_control_level_speed_course_altitude_sideslip, do: 4
  defmacro pilot_control_level_speed_courserate_altituderate_sideslip, do: 3
  defmacro pilot_control_level_roll_pitch_yawrate_throttle, do: 2
  defmacro pilot_control_level_rollrate_pitchrate_yawrate_throttle, do: 1

  defmacro input_inverted, do: -1
  defmacro input_not_inverted, do: 1
end
