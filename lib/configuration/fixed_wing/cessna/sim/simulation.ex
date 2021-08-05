defmodule Configuration.FixedWing.Cessna.Sim.Simulation do
  require Comms.Groups, as: Groups
  require Configuration.LoopIntervals, as: LoopIntervals
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
        send: [
          source_port: 49003,
          destination_port: 49000,
          destination_ip: {192, 168, 7, 200} #197
        ]
      ],
      ViaJoystick: [
        num_channels: 10,
      subscriber_groups: [Groups.command_channels()],
      publish_joystick_loop_interval_ms: LoopIntervals.joystick_channels_publish_ms()
      ],
      Interface: [
        controllers: [
          rollrate_aileron: [
            kp: 0.3,
            ki: 0.1,
            kd: 0,
            ff_multiplier: 0.318,
            output_min: -1.0,
            output_neutral: 0,
            output_max: 1.0,
            integrator_range: 0.26,
            integrator_airspeed_min_mps: 5.0
          ],
          pitchrate_elevator: [
            kp: 0.3,
            ki: 0.1,
            kd: 0,
            ff_multiplier: 0.318,
            output_min: -1.0,
            output_neutral: 0,
            output_max: 1.0,
            integrator_range: 0.26,
            integrator_airspeed_min_mps: 5.0
          ],
          yawrate_rudder: [
            kp: 0.3,
            ki: 0.0,
            kd: 0,
            ff_multiplier: 0.318,
            output_min: -1.0,
            output_neutral: 0,
            output_max: 1.0,
            integrator_range: 0.26,
            integrator_airspeed_min_mps: 5.0
          ]
        ]
      ]
    ]
  end
end
