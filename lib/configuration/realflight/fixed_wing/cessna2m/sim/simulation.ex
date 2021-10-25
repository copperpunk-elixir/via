defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Simulation do
  require ViaUtils.Shared.Groups, as: Groups
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaInputEvent.KeypressAction, as: KA
  alias ViaInputEvent.KeyCollection, as: KC

  @spec config() :: list()
  def config() do
    realflight() ++ sim_interface()
  end

  def sim_interface() do
    [
      {Simulation.Interface,
       [
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
       ]}
    ]
  end

  def realflight() do
    [
      {
        RealflightIntegration,
        realflight_ip: "192.168.7.136",
        dt_accel_gyro_group: Groups.dt_accel_gyro_val(),
        gps_itow_position_velocity_group: Groups.gps_itow_position_velocity_val(),
        gps_itow_relheading_group: Groups.gps_itow_relheading_val(),
        airspeed_group: Groups.airspeed_val(),
        downward_range_distance_group: Groups.downward_range_distance_val(),
        publish_dt_accel_gyro_interval_ms: 10,
        publish_gps_position_velocity_interval_ms: 200,
        publish_gps_relative_heading_interval_ms: 200,
        publish_airspeed_interval_ms: 200,
        publish_downward_range_distance_interval_ms: 200,
        downward_range_max_m: 40,
        downward_range_module: TerarangerEvoUart,
        sim_loop_interval_ms: 20,
        rc_passthrough: false
      }
    ]
  end

  def none() do
    []
  end

  def any() do
    joystick() ++ keyboard()
  end

  def joystick() do
    [
      {ViaInputEvent.Joystick,
       [
         channel_map: %{
           Frsky: %{
             :abs_x => 0,
             :abs_y => 1,
             :abs_z => 2,
             :abs_rx => 3,
             :abs_ry => 4,
             :abs_rz => 5,
             :abs_throttle => 6,
             :btn_b => 9
           },
           Spektrum: %{
             multiplier: 1 / 0.662,
             abs_z: 0,
             abs_rx: 1,
             abs_y: 2,
             abs_x: 3,
             abs_rz: 4,
             abs_throttle: 5,
             abs_ry: 6,
             none: 9
           }
         },
         default_values: %{
           0 => 0,
           1 => 0,
           2 => -1,
           3 => 0,
           4 => -1,
           5 => -1,
           6 => 0,
           7 => 0,
           8 => 0,
           9 => 1
         },
         subscriber_groups: [Groups.command_channels()],
         publish_joystick_loop_interval_ms: LoopIntervals.joystick_channels_publish_ms()
       ]}
    ]
  end

  def keyboard() do
    [
      {ViaInputEvent.Keyboard,
       [
         key_collections: %{
           roll_axis:
             KC.new_pcl(
               KA.new_discrete(-360, 360, 15, 0),
               KA.new_discrete(-60, 60, 5, 0),
               KA.new_discrete(-30, 30, 5, 0)
             ),
           pitch_axis:
             KC.new_pcl(
               KA.new_discrete(-180, 180, 15, 0),
               KA.new_discrete(-30, 30, 5, 0),
               KA.new_discrete(-5, 5, 1, 0)
             ),
           yaw_axis:
             KC.new_pcl(
               KA.new_discrete(-180, 180, 10, 0),
               KA.new_discrete(-45, 45, 5, 0),
               KA.new_discrete(-15, 15, 5, 0)
             ),
           thrust_axis:
             KC.new_pcl(
               KA.new_discrete(0, 1, 0.1, 0),
               KA.new_discrete(0, 1, 0.1, 0),
               KA.new_discrete(0, 65, 5, 0)
             ),
           flaps: KC.new_all(KA.new_discrete(0, 1, 0.5, 0)),
           gear: KC.new_all(KA.new_toggle(-1)),
           pcl: KC.new_all(KA.new_discrete(1, 4, 1, 1))
         },
         key_map: %{
           key_a: [{:yaw_axis, :subtract, []}],
           key_d: [{:yaw_axis, :add, []}],
           key_s: [{:thrust_axis, :subtract, []}],
           key_w: [{:thrust_axis, :add, []}],
           key_left: [{:roll_axis, :subtract, []}],
           key_right: [{:roll_axis, :add, []}],
           key_down: [{:pitch_axis, :subtract, []}],
           key_up: [{:pitch_axis, :add, []}],
           key_1: [
             {:pcl, :set, [1]},
             {:roll_axis, :set, [0]},
             {:pitch_axis, :set, [0]},
             {:yaw_axis, :set, [0]},
             {:thrust_axis, :set_value_for_output, :pcl_hold}
           ],
           key_2: [
             {:pcl, :set, [2]},
             {:roll_axis, :set, [0]},
             {:pitch_axis, :set, [0]},
             {:yaw_axis, :set, [0]},
             {:thrust_axis, :set_value_for_output, :pcl_hold}
           ],
           key_4: [
             {:pcl, :set, [4]},
             {:roll_axis, :set, [0]},
             {:pitch_axis, :set, [0]},
             {:yaw_axis, :set, [0]},
             {:thrust_axis, :set_value_for_output, :pcl_hold}
           ],
           key_f: [{:flaps, :increment, []}],
           key_g: [{:gear, :toggle, []}],
           key_k: [{:thrust_axis, :zero, []}],
           key_r: [{:roll_axis, :zero, []}],
           key_p: [{:pitch_axis, :zero, []}],
           key_y: [{:yaw_axis, :zero, []}]
         },
         channel_map: %{
           roll_axis: 0,
           pitch_axis: 1,
           thrust_axis: 2,
           yaw_axis: 3,
           flaps: 4,
           pcl: 5,
           gear: 9
         },
         default_values: %{
           0 => 0,
           1 => 0,
           2 => -1,
           3 => 0,
           4 => -1,
           5 => -1,
           6 => 0,
           7 => 0,
           8 => 0,
           9 => 1
         },
         subscriber_groups: [Groups.command_channels()],
         publish_keyboard_loop_interval_ms: LoopIntervals.keyboard_channels_publish_ms()
       ]}
    ]
  end
end
