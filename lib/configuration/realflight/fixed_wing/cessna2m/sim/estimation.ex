defmodule Configuration.RealFlight.FixedWing.Cessna2m.Sim.Estimation do
  require Configuration.LoopIntervals, as: LoopIntervals
  @spec config() :: list()
  def config() do
    [
      Estimator: [
        min_speed_for_course: 1.0,
        ins_kf_type: ViaEstimation.Ekf.SevenState,
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
          expected_imu_dt_s: LoopIntervals.imu_receive_max_ms*(1.0e-3),

          # Mahony
          imu_config: [
            imu_type: ViaEstimation.Imu.Mahony,
            imu_parameters: [
              kp: 0.1,
              ki: 0
            ]
          ]
        ],
        agl_kf_type: ViaEstimation.Ekf.Agl,
        agl_kf_config: [
          q_att_sq: 0.00274,
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
