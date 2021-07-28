defmodule Estimation.Imu.Mahony do
  require Logger
  require ViaUtils.Constants, as: VC
  # @accel_mag_min 9.0
  # @accel_mag_max 10.0
  @accel_xy_mag_max 1.0
  @accel_z_delta_mag_max 0.2

  defstruct quat: {1.0, 0, 0, 0},
            kp: 0,
            ki: 0,
            integral_fbx: 0,
            integral_fby: 0,
            integral_fbz: 0,
            roll_rad: 0,
            pitch_rad: 0,
            yaw_rad: 0

  @spec new(float(), float()) :: struct()
  def new(kp, ki) do
    %Estimation.Imu.Mahony{kp: kp, ki: ki}
  end

  @spec update(struct(), map()) :: struct()
  def update(imu, dt_accel_gyro) do
    dt_s = dt_accel_gyro.dt_s
    ax = dt_accel_gyro.ax_mpss
    ay = dt_accel_gyro.ay_mpss
    az = dt_accel_gyro.az_mpss
    {q0, q1, q2, q3} = imu.quat

    {gx, gy, gz, integral_fbx, integral_fby, integral_fbz} =
      if ax != 0 or ay != 0 or az != 0 do
        # Normalise accelerometer measurement
        {ax, ay, az, kp, ki, accel_mag_in_range} =
          normalized_accel_and_in_range(
            ax,
            ay,
            az,
            imu.kp,
            imu.ki
          )

        # Only use the accel to correct if the accel values are within range
        if accel_mag_in_range do
          # Logger.debug("good accel mag")

          # Estimated direction of gravity and vector perpendicular to magnetic flux
          vx = 2.0 * (q1 * q3 - q0 * q2)
          vy = 2.0 * (q0 * q1 + q2 * q3)
          vz = q0 * q0 - q1 * q1 - q2 * q2 + q3 * q3

          # Error is sum of cross product between estimated and measured direction of gravity
          ex = ay * vz - az * vy
          ey = az * vx - ax * vz
          ez = ax * vy - ay * vx

          # Compute and apply integral feedback if enabled
          {integral_fbx, integral_fby, integral_fbz} =
            if ki > 0 do
              # integral error scaled by Ki
              integral_fbx = imu.integral_fbx + ex
              integral_fby = imu.integral_fby + ey
              integral_fbz = imu.integral_fbz + ez
              {integral_fbx, integral_fby, integral_fbz}
            else
              {0, 0, 0}
            end

          # Apply proportional feedback
          gx = dt_accel_gyro.gx_rps + kp * ex + ki * integral_fbx
          gy = dt_accel_gyro.gy_rps + kp * ey + ki * integral_fby
          gz = dt_accel_gyro.gz_rps + kp * ez + ki * integral_fbz

          # Logger.error(
          #   "dt gx pre/post: #{ViaUtils.Format.eftb(dt_s, 4)}: #{ViaUtils.Format.eftb_deg(dt_accel_gyro.gx_rps, 1)}/#{ViaUtils.Format.eftb_deg(gx, 1)}"
          # )

          {gx, gy, gz, integral_fbx, integral_fby, integral_fbz}
        else
          {dt_accel_gyro.gx_rps, dt_accel_gyro.gy_rps, dt_accel_gyro.gz_rps, 0, 0, 0}
        end
      else
        {dt_accel_gyro.gx_rps, dt_accel_gyro.gy_rps, dt_accel_gyro.gz_rps, imu.integral_fbx,
         imu.integral_fby, imu.integral_fbz}
      end

    # Integrate rate of change of quaternion
    # pre-multiply common factors
    pa = q1
    pb = q2
    pc = q3
    half_dt_s = dt_s * 0.5

    q0 = q0 + (-q1 * gx - q2 * gy - q3 * gz) * half_dt_s
    q1 = pa + (q0 * gx + pb * gz - pc * gy) * half_dt_s
    q2 = pb + (q0 * gy - pa * gz + pc * gx) * half_dt_s
    q3 = pc + (q0 * gz + pa * gy - pb * gx) * half_dt_s

    # Normalise quaternion
    q_mag_inv = 1 / :math.sqrt(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3)
    q0 = q0 * q_mag_inv
    q1 = q1 * q_mag_inv
    q2 = q2 * q_mag_inv
    q3 = q3 * q_mag_inv

    roll_rad = :math.atan2(2.0 * (q0 * q1 + q2 * q3), 1.0 - 2.0 * (q1 * q1 + q2 * q2))
    pitch_rad = :math.asin(2.0 * (q0 * q2 - q3 * q1))

    yaw_rad =
      :math.atan2(2.0 * (q0 * q3 + q1 * q2), 1.0 - 2.0 * (q2 * q2 + q3 * q3))
      |> ViaUtils.Math.constrain_angle_to_compass()

    # IO.puts("rpy: #{ViaUtils.Format.eftb_list([roll_rad, pitch_rad, yaw_rad], 3,",")}")

    %{
      imu
      | quat: {q0, q1, q2, q3},
        integral_fbx: integral_fbx,
        integral_fby: integral_fby,
        integral_fbz: integral_fbz,
        roll_rad: roll_rad,
        pitch_rad: pitch_rad,
        yaw_rad: yaw_rad
    }
  end

  @spec normalized_accel_and_in_range(float(), float(), float(), float(), float()) :: tuple()
  def normalized_accel_and_in_range(ax, ay, az, kp, ki) do
    # We will eventually have logic to select kp and ki based on the acceleration values
    # i.e., if accel is primarily due to gravity (mag ~= 1.0g), we can have a larger gain
    accel_mag = :math.sqrt(ax * ax + ay * ay + az * az)
    # Logger.debug("accel: #{ViaUtils.Format.eftb_map(%{ax: ax, ay: ay, az: az}, 3)}")
    # Logger.info("accel mag: #{ViaUtils.Format.eftb(accel_mag, 5)}")
    z_minus_gravity_abs = abs(az + VC.gravity())

    if z_minus_gravity_abs < @accel_z_delta_mag_max and abs(ax) < @accel_xy_mag_max and
         abs(ay) < @accel_xy_mag_max do
      # Logger.error("good accel")
      # WE MUST TAKE THE OPPOSITE SIGN OF THE ACCELERATION FOR THESE EQUATIONS TO WORK
      # Use reciprocal for division
      accel_mag = 1 / accel_mag
      ax = -ax * accel_mag
      ay = -ay * accel_mag
      az = -az * accel_mag
      {ax, ay, az, kp, ki, true}
    else
      {0, 0, 0, 0, 0, false}
    end
  end
end
