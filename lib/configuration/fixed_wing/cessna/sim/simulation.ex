defmodule Configuration.FixedWing.Cessna.Sim.Simulation do
  require Comms.Groups, as: Groups
  @spec config() :: list()
  def config do
    [
      XplaneIntegration: [
        receive: [
          port: 49002,
          dt_accel_gyro_group: Groups.dt_accel_gyro_val(),
          gps_itow_position_velocity_group: Groups.gps_itow_position_velocity_val(),
          gps_itow_relheading_group: Groups.gps_itow_relheading_val(),
          airspeed_group: Groups.airspeed_val(),
          downward_tof_distance_group: Groups.downward_tof_distance_val(),
          publish_dt_accel_gyro_interval_ms: 5,
          publish_gps_position_velocity_interval_ms: 200,
          publish_gps_relative_heading_interval_ms: 200,
          publish_airspeed_interval_ms: 200,
          publish_downward_tof_distance_interval_ms: 200
        ],
        send: [port: 49000]
      ]
    ]
  end
end
