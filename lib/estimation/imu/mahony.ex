defmodule Estimation.Imu.Mahony do
  require Logger
  @accel_mag_min 9.6
  @accel_mag_max 10.0

  defstruct q0: 1.0,
            q1: 0.0,
            q2: 0.0,
            q3: 0.0,
            two_kp: 0,
            two_ki: 0,
            integral_fbx: 0,
            integral_fby: 0,
            integral_fbz: 0,
            roll: 0,
            pitch: 0,
            yaw: 0

  @spec new(float(), float()) :: struct()
  def new(two_kp, two_ki) do
    %Estimation.Imu.Mahony{two_kp: two_kp, two_ki: two_ki}
  end

  @spec update(struct(), list()) :: struct()
  def update(imu, dt_accel_gyro) do
    [dt, ax, ay, az, gx, gy, gz] = dt_accel_gyro
    {gx, gy, gz, integral_fbx, integral_fby, integral_fbz} =
      if ax != 0 or ay != 0 or az != 0 do
        # Auxiliary variables to avoid repeated arithmetic
        # Compute DCM since we've got this multiplication stuff going

        # Normalise accelerometer measurement
        accel_mag = :math.sqrt(ax * ax + ay * ay + az * az)
        # Only use the accel to correct if the magnitude is less than the threshold
        # (which means the inverse is greater than the threshold)
        if accel_mag > @accel_mag_min and accel_mag < @accel_mag_max do
          Logger.debug("good accel mag: #{accel_mag}")
          ax = ax / accel_mag
          ay = ay / accel_mag
          az = az / accel_mag

          # Estimated direction of gravity and vector perpendicular to magnetic flux

          halfvx = imu.q1 * imu.q3 - imu.q0 * imu.q2
          halfvy = imu.q0 * imu.q1 + imu.q2 * imu.q3
          halfvz = imu.q0 * imu.q0 - 0.5 + imu.q3 * imu.q3

          # Error is sum of cross product between estimated and measured direction of gravity
          halfex = ay * halfvz - az * halfvy
          halfey = az * halfvx - ax * halfvz
          halfez = ax * halfvy - ay * halfvx

          # Compute and apply integral feedback if enabled
          two_ki = imu.two_ki

          {integral_fbx, integral_fby, integral_fbz} =
            if two_ki > 0 do
              # integral error scaled by Ki
              integral_fbx = imu.integral_fbx + two_ki * halfex * dt
              integral_fby = imu.integral_fby + two_ki * halfey * dt
              integral_fbz = imu.integral_fbz + two_ki * halfez * dt
              {integral_fbx, integral_fby, integral_fbz}
            else
              {0, 0, 0}
            end

          # Apply proportional feedback
          two_kp = imu.two_kp
          gx = gx + two_kp * halfex + integral_fbx
          gy = gy + two_kp * halfey + integral_fby
          gz = gz + two_kp * halfez + integral_fbz
          {gx, gy, gz, integral_fbx, integral_fby, integral_fbz}
        else
          {gx, gy, gz, imu.integral_fbx, imu.integral_fby, imu.integral_fbz}
        end
      else
        {gx, gy, gz, imu.integral_fbx, imu.integral_fby, imu.integral_fbz}
      end

    # Integrate rate of change of quaternion
    # pre-multiply common factors
    gx = gx * 0.5 * dt
    gy = gy * 0.5 * dt
    gz = gz * 0.5 * dt
    qa = imu.q0
    qb = imu.q1
    qc = imu.q2
    q3 = imu.q3
    q0 = imu.q0 + (-qb * gx - qc * gy - q3 * gz)
    q1 = imu.q1 + (qa * gx + qc * gz - q3 * gy)
    q2 = imu.q2 + (qa * gy - qb * gz + q3 * gx)
    q3 = q3 + (qa * gz + qb * gy - qc * gx)

    # Normalise quaternion
    q_mag = :math.sqrt(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3)
    q0 = q0 / q_mag
    q1 = q1 / q_mag
    q2 = q2 / q_mag
    q3 = q3 / q_mag


    roll = :math.atan2(2.0*(imu.q0*imu.q1 + imu.q2 * imu.q3), (1.0 - 2.0*(imu.q1*imu.q1 + imu.q2 * imu.q2)))
    pitch = :math.asin(2.0 * (imu.q0*imu.q2 - imu.q3 * imu.q1))
    yaw = :math.atan2(2.0*(imu.q0*imu.q3 + imu.q1 * imu.q2), (1.0 - 2.0*(imu.q2*imu.q2 + imu.q3 * imu.q3)))

    %{
      imu
      | q0: q0,
        q1: q1,
        q2: q2,
        q3: q3,
        integral_fbx: integral_fbx,
        integral_fby: integral_fby,
        integral_fbz: integral_fbz,
        roll: roll,
        pitch: pitch,
        yaw: yaw
    }
  end
end
