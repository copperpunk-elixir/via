defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Uart.Companion do
  require ViaUtils.Shared.GoalNames, as: SGN
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaUtils.Shared.ControlTypes, as: SCT

  def config() do
    [
      {SVN.vehicle_id(), Configuration.Utils.get_vehicle_id(__MODULE__)},
      channel_names: %{
        SCT.pilot_control_level_1() => %{
          0 => SGN.aileron_scaled(),
          1 => SGN.elevator_scaled(),
          2 => SGN.throttle_scaled(),
          3 => SGN.rudder_scaled()
        },
        SGN.any_pcl() => %{
          4 => SGN.flaps_scaled(),
          5 => SGN.gear_scaled()
        }
      },
      expected_imu_receive_interval_ms: 20,
      controllers: [
        {SCT.rollrate_aileron_pid(),
         [
           {SCT.kp(), 0.3},
           {SCT.ki(), 0.1},
           {SCT.kd(), 0},
           {SCT.feed_forward_multiplier(), 0.318},
           {SCT.output_min(), -1.0},
           {SCT.output_neutral(), 0},
           {SCT.output_max(), 1.0},
           {SCT.integrator_range(), 0.26},
           {SCT.integrator_airspeed_min_mps(), 5.0}
         ]},
        {SCT.pitchrate_elevator_pid(),
         [
           {SCT.kp(), 0.6},
           {SCT.ki(), 0.5},
           {SCT.kd(), 0},
           {SCT.feed_forward_multiplier(), 0.318},
           {SCT.output_min(), -1.0},
           {SCT.output_neutral(), 0},
           {SCT.output_max(), 1.0},
           {SCT.integrator_range(), 0.26},
           {SCT.integrator_airspeed_min_mps(), 5.0}
         ]},
        {SCT.yawrate_rudder_pid(),
         [
           {SCT.kp(), 0.3},
           {SCT.ki(), 0.0},
           {SCT.kd(), 0},
           {SCT.feed_forward_multiplier(), 0.318},
           {SCT.output_min(), -1.0},
           {SCT.output_neutral(), 0},
           {SCT.output_max(), 1.0},
           {SCT.integrator_range(), 0.26},
           {SCT.integrator_airspeed_min_mps(), 5.0}
         ]}
      ]
    ]
  end
end
