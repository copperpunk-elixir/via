defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.Companion do
  require ViaUtils.Shared.GoalNames, as: SGN

  def config() do
    [
      vehicle_id: Configuration.Utils.get_vehicle_id(__MODULE__),
      channel_names: %{
        bodyrate: %{
          0 => SGN.aileron_scaled(),
          1 => SGN.elevator_scaled(),
          2 => SGN.throttle_scaled(),
          3 => SGN.rudder_scaled()
        },
        any_pcl: %{
          4 => SGN.flaps_scaled(),
          5 => SGN.gear_scaled()
        }
      },
      expected_imu_receive_interval_ms: 20,
      controllers: [
        rollrate_aileron: [
          kp: 0.02,
          ki: 0.0,
          kd: 0,
          ff_multiplier: 0.128,
          output_min: -1.0,
          output_neutral: 0,
          output_max: 1.0,
          integrator_range: 0.26,
          integrator_airspeed_min_mps: 5.0
        ],
        pitchrate_elevator: [
          kp: 0.5,
          ki: 0.5,
          kd: 0,
          ff_multiplier: 0.318,
          output_min: -1.0,
          output_neutral: 0,
          output_max: 1.0,
          integrator_range: 2.0,
          integrator_airspeed_min_mps: 5.0
        ],
        yawrate_rudder: [
          kp: 0.03,
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
  end
end
