defmodule Configuration.FixedWing.Cessna.Sim.Estimation do
  @spec config() :: list()
  def config() do
    [
      Estimator: [
        attitude_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
        position_speed_course_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
        accel_gyro_rate_expected_interval_ms: 5,
        gps_expected_interval_ms: 200,
        range_expected_interval_ms: 100,
        min_speed_for_course: 1.0,

        ins_kf_type: Ekf.SevenState,
        ins_kf_config: [
          init_std_devs: [0.1, 0.1, 0.3, 0.1, 0.1, 0.3, 0.05],
          qpos_xy_std: 0.1,
          qpos_z_std: 0.05,
          qvel_xy_std: 0.05,
          qvel_z_std: 0.1,
          qyaw_std: 0.08,
          gpspos_xy_std: 0.715,
          gpspos_z_std: 2.05,
          gpsvel_xy_std: 0.088,
          gpsvel_z_std: 0.31,
          gpsyaw_std: 0.02,

          # Mahony
          imu_kp: 1.0,
          imu_ki: 0
        ],

        agl_kf_type: Ekf.Agl,
        agl_kf_config: [
          q_att_sq: 0.00274, # 3deg^2
          q_zdot_sq: 0.25,
          q_z_sq: 0.1,
          r_range_sq: 1.0,
          roll_max_rad: 0.52,
          pitch_max_rad: 0.52
        ]
      ]
    ]
  end
end
