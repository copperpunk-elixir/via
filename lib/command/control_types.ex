defmodule Command.ControlTypes do
  defmacro autopilot_control_mode_full_auto, do: 3
  defmacro autopilot_control_mode_controller_assist, do: 2
  defmacro autopilot_control_mode_remote_pilot_override, do: 1
  defmacro input_inverted, do: -1
  defmacro input_not_inverted, do: 1

  # groundspeed_courserate_altituderate_sideslip
  defmacro pilot_control_level_4, do: 4
  # groundspeed_course_altitude_sideslip
  defmacro pilot_control_level_3, do: 3
  # roll_pitch_deltayaw_throttle
  defmacro pilot_control_level_2, do: 2
  # rollrate_pitchrate_yawrate_throttle
  defmacro pilot_control_level_1, do: 1
  defmacro remote_pilot_override, do: 0
end
