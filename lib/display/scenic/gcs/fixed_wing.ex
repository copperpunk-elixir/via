defmodule Display.Scenic.Gcs.FixedWing do
  use Scenic.Scene
  require Logger
  require ViaUtils.Comms.Groups, as: Groups
  require Command.ControlTypes, as: CCT

  import Scenic.Primitives
  # @body_offset 80
  @font_size 24
  @battery_font_size 20
  @degrees "°"
  # @radians "rads"
  @dps "°/s"
  @meters "m"
  @mps "m/s"
  @pct "%"

  # @offset_x 0
  # @width 300
  # @height 50
  # @labels {"", "", ""}
  @rect_border 6
  @ip_address_loop :ip_address_loop

  @moduledoc """
  This version of `Sensor` illustrates using spec functions to
  construct the display graph. Compare this with `Sensor` which uses
  anonymous functions.
  """

  # ============================================================================
  @impl true
  def init(_, opts) do
    # Logger.debug("Sensor.init: #{inspect(opts)}")

    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} =
      opts[:viewport]
      |> Scenic.ViewPort.info()

    # col = vp_width / 12
    label_value_width = 300
    label_value_height = 50
    goals_width = 500
    goals_height = 50
    battery_width = 400
    battery_height = 40
    ip_width = 300
    ip_height = 40
    cluster_status_side = 100
    # build the graph
    offset_x_origin = 10
    offset_y_origin = 10
    spacer_y = 20

    graph = Scenic.Graph.build(font: :roboto, font_size: 16, theme: :dark)

    {graph, offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_columns_to_graph(graph, %{
        width: label_value_width,
        height: 4 * label_value_height,
        offset_x: offset_x_origin,
        offset_y: offset_y_origin,
        spacer_y: spacer_y,
        labels: ["latitude", "longitude", "altitude", "AGL"],
        ids: [:lat, :lon, :alt, :agl],
        font_size: @font_size
      })

    {graph, offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_columns_to_graph(graph, %{
        width: label_value_width,
        height: 3 * label_value_height,
        offset_x: offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["airspeed", "speed", "course"],
        ids: [:airspeed, :speed, :course],
        font_size: @font_size
      })

    {graph, _offset_x, _offset_y} =
      Display.Scenic.Gcs.Utils.add_columns_to_graph(graph, %{
        width: label_value_width,
        height: 3 * label_value_height,
        offset_x: offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["roll", "pitch", "yaw"],
        ids: [:roll, :pitch, :yaw],
        font_size: @font_size
      })

    goals_offset_x = 60 + label_value_width

    {graph, _offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
        id: {:goals, 4},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y_origin,
        spacer_y: spacer_y,
        labels: ["speed", "course rate", "altitude rate", "sideslip"],
        ids: [:speed_4_cmd, :course_rate_cmd, :altitude_rate_cmd, :sideslip_4_cmd],
        font_size: @font_size
      })

    {graph, _offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
        id: {:goals, 3},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["speed", "course", "altitude", "sideslip"],
        ids: [:speed_3_cmd, :course_cmd, :altitude_cmd, :sideslip_3_cmd],
        font_size: @font_size
      })

    {graph, _offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
        id: {:goals, 2},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["thrust", "roll", "pitch", "yaw"],
        ids: [:thrust_cmd, :roll_cmd, :pitch_cmd, :deltayaw_cmd],
        font_size: @font_size
      })

    {graph, _offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
        id: {:goals, 1},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["thrust", "rollrate", "pitchrate", "yawrate"],
        ids: [:throttle_cmd, :rollrate_cmd, :pitchrate_cmd, :yawrate_cmd],
        font_size: @font_size
      })

    {graph, _offset_x, offset_y} =
      Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
        id: :ip_address_row,
        width: ip_width,
        height: 2 * ip_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["IP address"],
        ids: [:ip_address],
        font_size: @font_size
      })

    # cluster_status_offset_x = vp_width - cluster_status_side - 40
    # cluster_status_offset_y = vp_height - cluster_status_side - 20

    # {graph, _offset_x, _offset_y} =
    #   Display.Scenic.Gcs.Utils.add_rectangle_to_graph(graph, %{
    #     id: :cluster_status,
    #     width: cluster_status_side,
    #     height: cluster_status_side,
    #     offset_x: cluster_status_offset_x,
    #     offset_y: cluster_status_offset_y,
    #     fill: :red
    #   })

    # # Save Log
    # {graph, _offset_x, button_offset_y} =
    #   Display.Scenic.Gcs.Utils.add_save_log_to_graph(graph, %{
    #     button_id: :save_log,
    #     text_id: :save_log_filename,
    #     button_width: 100,
    #     button_height: 35,
    #     offset_x: 10,
    #     offset_y: vp_height - 100,
    #     font_size: @font_size,
    #     text_width: 400
    #   })

    # {graph, _offset_x, _offset_y} =
    #   Display.Scenic.Gcs.Utils.add_peripheral_control_to_graph(graph, %{
    #     allow_id: {:peri_ctrl, :allow},
    #     deny_id: {:peri_ctrl, :deny},
    #     button_width: 150,
    #     button_height: 35,
    #     offset_x: 10,
    #     offset_y: button_offset_y + 10,
    #     font_size: @font_size,
    #     text_width: 400
    #   })

    # batteries = ["cluster", "motor"]

    # {graph, _offset_x, _offset_y} =
    #   Enum.reduce(batteries, {graph, goals_offset_x, offset_y}, fn battery,
    #                                                                {graph, off_x, off_y} ->
    #     ids = [{battery, :V}, {battery, :I}, {battery, :mAh}]
    #     # battery_str = Atom.to_string(battery)
    #     labels = [battery <> " V", battery <> " I", battery <> " mAh"]

    #     Display.Scenic.Gcs.Utils.add_rows_to_graph(graph, %{
    #       id: {:battery, battery},
    #       width: battery_width,
    #       height: 2 * battery_height,
    #       offset_x: off_x,
    #       offset_y: off_y,
    #       spacer_y: spacer_y,
    #       labels: labels,
    #       ids: ids,
    #       font_size: @battery_font_size
    #     })
    #   end)

    # subscribe to the simulated temperature sensor
    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude())
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_position_velocity())
    ViaUtils.Comms.join_group(__MODULE__, Groups.current_pilot_control_level_and_commands())

    ip_address_timer = ViaUtils.Process.start_loop(
      self(),
      1000,
      @ip_address_loop
    )

    # ViaUtils.Comms.join_group(__MODULE__, :tx_battery)
    # ViaUtils.Comms.join_group(__MODULE__, :cluster_status)
    state = %{
      graph: graph,
      save_log_file: "",
      ip_address_timer: ip_address_timer
    }

    {:ok, state, push: graph}
  end

  def handle_info(@ip_address_loop, state) do
    Logger.debug("ip loop")
    ip_address_string =
      if Via.Application.is_target() do
        ip_address = Network.Connection.get_ip_address_eth0()
        if is_nil(ip_address), do: "", else: VintageNet.IP.ip_to_string(ip_address)
      else
        "Check IP in terminal."
      end

    graph = Scenic.Graph.modify(state.graph, :ip_address, &text(&1, ip_address_string))
    ip_address_timer =
      if ip_address_string != "" do
        ViaUtils.Process.stop_loop(state.ip_address_timer)
      else
        state.ip_address_timer
      end
    {:noreply, %{state | graph: graph, ip_address_timer: ip_address_timer}, push: graph}
  end

  # --------------------------------------------------------
  # receive PV updates from the vehicle
  @impl true
  def handle_cast({Groups.estimation_attitude(), attitude}, state) do
    # Logger.debug("position: #{ViaUtils.LatLonAlt.to_string(position)}")
    roll = Map.get(attitude, :roll_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)
    pitch = Map.get(attitude, :pitch_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

    yaw =
      Map.get(attitude, :yaw_rad, 0)
      |> ViaUtils.Math.constrain_angle_to_compass()
      |> ViaUtils.Math.rad2deg()
      |> ViaUtils.Format.eftb(1)

    graph =
      state.graph
      |> Scenic.Graph.modify(:roll, &text(&1, roll <> @degrees))
      |> Scenic.Graph.modify(:pitch, &text(&1, pitch <> @degrees))
      |> Scenic.Graph.modify(:yaw, &text(&1, yaw <> @degrees))

    {:noreply, %{state | graph: graph}, push: graph}
  end

  @impl true
  def handle_cast({Groups.estimation_position_velocity(), position, velocity}, state) do
    lat =
      Map.get(position, :latitude_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(5)

    lon =
      Map.get(position, :longitude_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(5)

    alt = Map.get(position, :altitude_m, 0) |> ViaUtils.Format.eftb(2)
    agl = Map.get(position, :agl_m, 0) |> ViaUtils.Format.eftb(2)

    # v_down = ViaUtils.Format.eftb(velocity.down,1)
    airspeed = Map.get(velocity, :airspeed_mps, 0) |> ViaUtils.Format.eftb(1)
    # Logger.debug("disp #{airspeed}")
    speed = Map.get(velocity, :groundspeed_mps, 0) |> ViaUtils.Format.eftb(1)

    course =
      Map.get(velocity, :course_rad, 0)
      |> ViaUtils.Math.constrain_angle_to_compass()
      |> ViaUtils.Math.rad2deg()
      |> ViaUtils.Format.eftb(1)

    graph =
      Scenic.Graph.modify(state.graph, :lat, &text(&1, lat <> @degrees))
      |> Scenic.Graph.modify(:lon, &text(&1, lon <> @degrees))
      |> Scenic.Graph.modify(:alt, &text(&1, alt <> @meters))
      |> Scenic.Graph.modify(:agl, &text(&1, agl <> @meters))
      |> Scenic.Graph.modify(:airspeed, &text(&1, airspeed <> @mps))
      |> Scenic.Graph.modify(:speed, &text(&1, speed <> @mps))
      |> Scenic.Graph.modify(:course, &text(&1, course <> @degrees))

    {:noreply, %{state | graph: graph}, push: graph}
  end

  def handle_cast({Groups.current_pilot_control_level_and_commands(), pcl, all_cmds}, state) do
    # Logger.debug("gcs rx #{pcl}/#{inspect(all_cmds)}")
    graph = state.graph

    graph =
      if pcl < CCT.pilot_control_level_1() do
        clear_text_values(graph, [:rollrate_cmd, :pitchrate_cmd, :yawrate_cmd, :throttle_cmd])
      else
        cmds = Map.get(all_cmds, CCT.pilot_control_level_1(), %{})

        rollrate =
          Map.get(cmds, :rollrate_rps, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

        pitchrate =
          Map.get(cmds, :pitchrate_rps, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

        yawrate =
          Map.get(cmds, :yawrate_rps, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

        throttle = (Map.get(cmds, :throttle_scaled, 0) * 100) |> ViaUtils.Format.eftb(0)

        graph
        |> Scenic.Graph.modify(:rollrate_cmd, &text(&1, rollrate <> @dps))
        |> Scenic.Graph.modify(:pitchrate_cmd, &text(&1, pitchrate <> @dps))
        |> Scenic.Graph.modify(:yawrate_cmd, &text(&1, yawrate <> @dps))
        |> Scenic.Graph.modify(:throttle_cmd, &text(&1, throttle <> @pct))
      end

    graph =
      if pcl < CCT.pilot_control_level_2() do
        clear_text_values(graph, [:roll_cmd, :pitch_cmd, :deltayaw_cmd, :thrust_cmd])
      else
        cmds = Map.get(all_cmds, CCT.pilot_control_level_2(), %{})

        roll = Map.get(cmds, :roll_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)
        pitch = Map.get(cmds, :pitch_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

        deltayaw =
          Map.get(cmds, :deltayaw_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

        thrust = (Map.get(cmds, :thrust_scaled, 0) * 100) |> ViaUtils.Format.eftb(0)

        graph
        |> Scenic.Graph.modify(:roll_cmd, &text(&1, roll <> @degrees))
        |> Scenic.Graph.modify(:pitch_cmd, &text(&1, pitch <> @degrees))
        |> Scenic.Graph.modify(:deltayaw_cmd, &text(&1, deltayaw <> @degrees))
        |> Scenic.Graph.modify(:thrust_cmd, &text(&1, thrust <> @pct))
      end

    graph =
      if pcl < CCT.pilot_control_level_3() do
        clear_text_values(graph, [:speed_3_cmd, :course_cmd, :altitude_cmd, :sideslip_3_cmd])
      else
        cmds = Map.get(all_cmds, CCT.pilot_control_level_3(), %{})
        speed = Map.get(cmds, :groundspeed_mps, 0) |> ViaUtils.Format.eftb(1)

        course =
          Map.get(cmds, :course_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

        altitude = Map.get(cmds, :altitude_m, 0) |> ViaUtils.Format.eftb(1)

        sideslip =
          Map.get(cmds, :sideslip_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

        graph
        |> Scenic.Graph.modify(:speed_3_cmd, &text(&1, speed <> @mps))
        |> Scenic.Graph.modify(:course_cmd, &text(&1, course <> @degrees))
        |> Scenic.Graph.modify(:altitude_cmd, &text(&1, altitude <> @meters))
        |> Scenic.Graph.modify(:sideslip_3_cmd, &text(&1, sideslip <> @degrees))
      end

    graph =
      if pcl < CCT.pilot_control_level_4() do
        clear_text_values(graph, [
          :speed_4_cmd,
          :course_rate_cmd,
          :altitude_rate_cmd,
          :sideslip_4_cmd
        ])
      else
        cmds = Map.get(all_cmds, CCT.pilot_control_level_4(), %{})
        speed = Map.get(cmds, :groundspeed_mps, 0) |> ViaUtils.Format.eftb(1)

        course_rate =
          Map.get(cmds, :course_rate_rps, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

        altitude_rate = Map.get(cmds, :altitude_rate_mps, 0) |> ViaUtils.Format.eftb(1)

        sideslip =
          Map.get(cmds, :sideslip_rad, 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

        graph
        |> Scenic.Graph.modify(:speed_4_cmd, &text(&1, speed <> @mps))
        |> Scenic.Graph.modify(:course_rate_cmd, &text(&1, course_rate <> @dps))
        |> Scenic.Graph.modify(:altitude_rate_cmd, &text(&1, altitude_rate <> @mps))
        |> Scenic.Graph.modify(:sideslip_4_cmd, &text(&1, sideslip <> @degrees))
      end

    graph = update_pilot_control_level(pcl, graph)
    {:noreply, %{state | graph: graph}, push: graph}
  end

  # def handle_cast({:tx_battery, battery_id, voltage_V, current_A, energy_mAh}, state) do
  #   voltage = ViaUtils.Format.eftb(voltage_V, 2)
  #   current = ViaUtils.Format.eftb(current_A, 2)
  #   mAh = ViaUtils.Format.eftb(energy_mAh, 0)
  #   {battery_type, _battery_channel} = Health.Hardware.Battery.get_type_channel_for_id(battery_id)
  #   # Logger.debug("tx battery type: #{battery_type}")
  #   graph =
  #     state.graph
  #     |> Scenic.Graph.modify({battery_type, :V}, &text(&1,voltage <> "V"))
  #     |> Scenic.Graph.modify({battery_type, :I}, &text(&1,current <> "A"))
  #     |> Scenic.Graph.modify({battery_type, :mAh}, &text(&1,mAh <> "mAh"))
  #   {:noreply, %{state | graph: graph}, push: graph}
  # end

  def handle_cast({:cluster_status, cluster_status}, state) do
    fill = if cluster_status == 1, do: :green, else: :red

    graph =
      state.graph
      |> Scenic.Graph.modify(:cluster_status, &update_opts(&1, fill: fill))

    {:noreply, %{state | graph: graph}, push: graph}
  end

  def update_pilot_control_level(pilot_control_level, graph) do
    Enum.reduce(CCT.pilot_control_level_4()..CCT.pilot_control_level_1(), graph, fn pcl, acc ->
      if pcl == pilot_control_level do
        Scenic.Graph.modify(
          acc,
          {:goals, pcl},
          &update_opts(&1, stroke: {@rect_border, :green})
        )
      else
        Scenic.Graph.modify(
          acc,
          {:goals, pcl},
          &update_opts(&1, stroke: {@rect_border, :white})
        )
      end
    end)
  end

  def clear_text_values(graph, value_ids) do
    Enum.reduce(
      value_ids,
      graph,
      fn id, acc ->
        Scenic.Graph.modify(acc, id, &text(&1, ""))
      end
    )
  end

  @impl Scenic.Scene
  def filter_event({:click, :save_log}, _from, state) do
    Logger.debug("Save Log to file: #{state.save_log_file} (NOT CONNECTED)")
    # save_log_proto = Display.Scenic.Gcs.Protobuf.SaveLog.new([filename: state.save_log_file])
    # save_log_encoded =Display.Scenic.Gcs.Protobuf.SaveLog.encode(save_log_proto)
    # Peripherals.Uart.Generic.construct_and_send_proto_message(:save_log_proto, save_log_encoded, Peripherals.Uart.Telemetry.Operator)
    {:cont, :event, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, {:peri_ctrl, action}}, _from, state) do
    Logger.debug("Change PeriCtrl #{action} (NOT CONNECTED)")
    # control_value =
    #   case action do
    #     :allow -> 1
    #     :deny -> 0
    #   end
    # Peripherals.Uart.Generic.construct_and_send_message(:change_peripheral_control, [control_value], Peripherals.Uart.Telemetry.Operator)
    {:cont, :event, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, _other}, _from, state) do
    {:cont, :event, state}
  end

  @impl Scenic.Scene
  def filter_event({:value_changed, :save_log_filename, filename}, _from, state) do
    {:cont, :event, %{state | save_log_file: filename}}
  end
end
