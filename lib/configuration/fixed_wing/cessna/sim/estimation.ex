defmodule Configuration.FixedWing.Cessna.Sim.Estimation do
  @spec config() :: list()
  def config() do
    [
      Estimator: [
        imu_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
        ins_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
        sca_values_slow_loop_interval_ms: Configuration.Generic.loop_interval_ms(:slow),
        accel_gyro_rate_expected_interval_ms: 5,
        gps_expected_interval_ms: 200,
        range_expected_interval_ms: 100,

        kf_type: Ekf.SevenState,
        kf_config: [
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
        ]
      ]
    ]
  end
end
