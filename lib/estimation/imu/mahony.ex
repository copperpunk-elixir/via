defmodule Estimation.Imu.Mahony do
  require Logger
  @accel_mag_min 9.6
  @accel_mag_max 10.0

  defstruct q0: 1.0,
            q1: 0.0,
            q2: 0.0,
            q3: 0.0,
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
    dt = dt_accel_gyro.dt
    ax = dt_accel_gyro.ax
    ay = dt_accel_gyro.ay
    az = dt_accel_gyro.az
    q0 = imu.q0
    q1 = imu.q1
    q2 = imu.q2
    q3 = imu.q3

    {gx, gy, gz, integral_fbx, integral_fby, integral_fbz} =
      if ax != 0 or ay != 0 or az != 0 do
        # Normalise accelerometer measurement
        {ax_norm, ay_norm, az_norm, kp, ki, accel_mag_in_range} =
          normalized_accel_and_in_range(
            ax,
            ay,
            az,
            imu.kp,
            imu.ki
          )

        # Only use the accel to correct if the accel values are within range
        if accel_mag_in_range do
          # Logger.debug("good accel mag: #{accel_mag}")
          # Estimated direction of gravity and vector perpendicular to magnetic flux
          halfvx = q1 * q3 - q0 * q2
          halfvy = q0 * q1 + q2 * q3
          halfvz = q0 * q0 - 0.5 + q3 * q3

          # Error is sum of cross product between estimated and measured direction of gravity
          halfex = ay_norm * halfvz - az_norm * halfvy
          halfey = az_norm * halfvx - ax_norm * halfvz
          halfez = ax_norm * halfvy - ay_norm * halfvx

          # Compute and apply integral feedback if enabled
          {integral_fbx, integral_fby, integral_fbz} =
            if ki > 0 do
              # integral error scaled by Ki
              integral_fbx = imu.integral_fbx + ki * halfex * dt
              integral_fby = imu.integral_fby + ki * halfey * dt
              integral_fbz = imu.integral_fbz + ki * halfez * dt
              {integral_fbx, integral_fby, integral_fbz}
            else
              {0, 0, 0}
            end

          # Apply proportional feedback
          gx = dt_accel_gyro.gx + kp * halfex + integral_fbx
          gy = dt_accel_gyro.gy + kp * halfey + integral_fby
          gz = dt_accel_gyro.gz + kp * halfez + integral_fbz
          {gx, gy, gz, integral_fbx, integral_fby, integral_fbz}
        else
          {dt_accel_gyro.gx, dt_accel_gyro.gy, dt_accel_gyro.gz, imu.integral_fbx,
           imu.integral_fby, imu.integral_fbz}
        end
      else
        {dt_accel_gyro.gx, dt_accel_gyro.gy, dt_accel_gyro.gz, imu.integral_fbx, imu.integral_fby,
         imu.integral_fbz}
      end

    # Integrate rate of change of quaternion
    # pre-multiply common factors
    gx = gx * 0.5 * dt
    gy = gy * 0.5 * dt
    gz = gz * 0.5 * dt

    qa = q0
    qb = q1
    qc = q2

    q0 = q0 + (-qb * gx - qc * gy - q3 * gz)
    q1 = q1 + (qa * gx + qc * gz - q3 * gy)
    q2 = q2 + (qa * gy - qb * gz + q3 * gx)
    q3 = q3 + (qa * gz + qb * gy - qc * gx)

    # Normalise quaternion
    q_mag_inv = 1 / :math.sqrt(q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3)
    q0 = q0 * q_mag_inv
    q1 = q1 * q_mag_inv
    q2 = q2 * q_mag_inv
    q3 = q3 * q_mag_inv

    roll_rad = :math.atan2(2.0 * (q0 * q1 + q2 * q3), 1.0 - 2.0 * (q1 * q1 + q2 * q2))
    pitch_rad = :math.asin(2.0 * (q0 * q2 - q3 * q1))
    yaw_rad = :math.atan2(2.0 * (q0 * q3 + q1 * q2), 1.0 - 2.0 * (q2 * q2 + q3 * q3))
    # IO.puts("rpy: #{ViaUtils.Format.eftb_list([roll_rad, pitch_rad, yaw_rad], 3,",")}")

    %{
      imu
      | q0: q0,
        q1: q1,
        q2: q2,
        q3: q3,
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

    if accel_mag > @accel_mag_min and accel_mag < @accel_mag_max do
      # WE MUST TAKE THE OPPOSITE SIGN OF THE ACCELERATION FOR THESE EQUATIONS TO WORK
      ax = -ax / accel_mag
      ay = -ay / accel_mag
      az = -az / accel_mag
      {ax, ay, az, kp, ki, true}
    else
      {0, 0, 0, 0, 0, false}
    end
  end
end
