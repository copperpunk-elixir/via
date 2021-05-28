defmodule Imu.Utils do
  @spec rotate_yaw_rad(struct(), float()) :: struct()
  def rotate_yaw_rad(imu, delta_yaw_rad) do
    yaw = imu.yaw_rad + delta_yaw_rad
    %{imu | yaw_rad: yaw}
    |> reset_quat()
  end

  @spec reset_quat(struct()) :: struct()
  def reset_quat(imu) do
    cr = :math.cos(imu.roll_rad * 0.5)
    sr = :math.sin(imu.roll_rad * 0.5)
    cp = :math.cos(imu.pitch_rad * 0.5)
    sp = :math.sin(imu.pitch_rad * 0.5)
    cy = :math.cos(imu.yaw_rad * 0.5)
    sy = :math.sin(imu.yaw_rad * 0.5)
    crcp = cr * cp
    spsy = sp * sy
    spcy = sp * cy
    srcp = sr * cp

    q0 = crcp * cy + sr * spsy
    q1 = srcp * cy - cr * spsy
    q2 = cr * spcy + srcp * sy
    q3 = crcp * sy - sr * spcy
    %{imu | q0: q0, q1: q1, q2: q2, q3: q3}
  end


end
