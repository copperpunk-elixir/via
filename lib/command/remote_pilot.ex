defmodule Command.RemotePilot do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.MessageHeaders, as: MessageHeaders
  require Command.ControlTypes, as: ControlTypes
  require Configuration.LoopIntervals, as: LoopIntervals
  alias ViaUtils.Watchdog

  @remote_pilot_goals_loop :remote_pilot_goals_loop
  @clear_values_list_callback :clear_values_list_callback
  @channel_values :channel_values

  def start_link(config) do
    Logger.debug("Start Command.RemotePilot GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    all_levels_channel_config = Keyword.fetch!(config, :all_levels_channel_config)

    pilot_control_level_channel =
      Map.fetch!(all_levels_channel_config, :pilot_control_level) |> elem(0)

    autopilot_control_mode_channel =
      Map.fetch!(all_levels_channel_config, :autopilot_control_mode) |> elem(0)

    all_levels_channel_config =
      Map.drop(all_levels_channel_config, [
        :pilot_control_level,
        :autopilot_control_mode
      ])

    state = %{
      num_channels: Keyword.fetch!(config, :num_channels),
      pilot_control_level_channel_config:
        Keyword.fetch!(config, :pilot_control_level_channel_config),
      all_levels_channel_config: all_levels_channel_config,
      remote_pilot_override_channels: Keyword.fetch!(config, :remote_pilot_override_channels),
      pilot_control_level_channel: pilot_control_level_channel,
      autopilot_control_mode_channel: autopilot_control_mode_channel,
      goals_sorter_classification_and_time_validity_ms:
        Keyword.fetch!(config, :goals_sorter_classification_and_time_validity_ms),
      channel_values_watchdog:
        Watchdog.new(
          {@clear_values_list_callback, @channel_values},
          2 * LoopIntervals.remote_pilot_goals_publish_ms()
        ),
      channel_values: []
    }

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.command_channels(), self())

    ViaUtils.Process.start_loop(
      self(),
      LoopIntervals.remote_pilot_goals_publish_ms(),
      @remote_pilot_goals_loop
    )

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.command_channels(), channel_values}, state) do
    # Logger.debug("Channel values: #{inspect(channel_values)}")
    {channel_values_watchdog, channel_values} =
      if length(channel_values) >= state.num_channels do
        {Watchdog.reset(state.channel_values_watchdog), channel_values}
      else
        {state.channel_values_watchdog, state.channel_values}
      end

    {:noreply,
     %{state | channel_values: channel_values, channel_values_watchdog: channel_values_watchdog}}
  end

  @impl GenServer
  def handle_info(@remote_pilot_goals_loop, state) do
    if !Enum.empty?(state.channel_values) do
      channel_value_map =
        Stream.zip(0..(state.num_channels - 1), state.channel_values) |> Enum.into(%{})

      autopilot_control_mode =
        Map.fetch!(channel_value_map, state.autopilot_control_mode_channel)
        |> autopilot_control_mode_from_float()

      # Logger.debug("acm: #{autopilot_control_mode}")

      cond do
        autopilot_control_mode == ControlTypes.autopilot_control_mode_controller_assist() ->
          pilot_control_level =
            Map.fetch!(channel_value_map, state.pilot_control_level_channel)
            |> pilot_control_level_from_float()

          pcl_channels =
            Map.fetch!(
              state.pilot_control_level_channel_config,
              pilot_control_level
            )

          # Logger.debug("pcl/channels: #{pilot_control_level}/#{inspect(channels)}")

          # Logger.debug("rp goals: #{ViaUtils.Format.eftb_map(goals, 3)}")
          pcl_goals = get_goals_for_channels(pcl_channels, channel_value_map)

          all_levels_goals =
            get_goals_for_channels(state.all_levels_channel_config, channel_value_map)

          {classification, time_validity_ms} =
            state.goals_sorter_classification_and_time_validity_ms

          goals = %{
            pcl: pcl_goals,
            all: all_levels_goals
          }

          ViaUtils.Comms.send_global_msg_to_group(
            __MODULE__,
            {MessageHeaders.global_group_to_sorter(), classification, time_validity_ms,
             {pilot_control_level, goals}},
            Groups.sorter_pilot_control_level_and_goals(),
            self()
          )

        autopilot_control_mode == ControlTypes.autopilot_control_mode_remote_pilot_override() ->
          override_commands =
            Enum.reduce(state.remote_pilot_override_channels, %{}, fn {channel_name,
                                                                       channel_number},
                                                                      acc ->
              Map.put(acc, channel_name, Map.fetch!(channel_value_map, channel_number))
            end)

          ViaUtils.Comms.send_global_msg_to_group(
            __MODULE__,
            {Groups.remote_pilot_override_commands(), override_commands},
            self()
          )

        true ->
          :ok
      end
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({@clear_values_list_callback, key}, state) do
    Logger.warn("clear #{inspect(key)}: #{inspect(Map.get(state, key))}")
    {:noreply, Map.put(state, key, [])}
  end

  @spec get_goals_for_channels(map(), map()) :: map()
  def get_goals_for_channels(channels, channel_value_map) do
    Enum.reduce(channels, %{}, fn {channel_name, {channel_number, channel_config}}, acc ->
      output =
        get_goal_from_rx_value(
          Map.fetch!(channel_value_map, channel_number),
          channel_config
        )

      Map.put(acc, channel_name, output)
    end)
  end

  @spec autopilot_control_mode_from_float(float()) :: integer()
  def autopilot_control_mode_from_float(acm_float) do
    cond do
      acm_float > 0.5 -> ControlTypes.autopilot_control_mode_remote_pilot_override()
      acm_float > -0.5 -> ControlTypes.autopilot_control_mode_controller_assist()
      true -> ControlTypes.autopilot_control_mode_full_auto()
    end
  end

  @spec pilot_control_level_from_float(float()) :: integer()
  def pilot_control_level_from_float(pcl_float) do
    cond do
      pcl_float > 0.5 -> ControlTypes.pilot_control_level_4()
      pcl_float > -0.5 -> ControlTypes.pilot_control_level_2()
      true -> ControlTypes.pilot_control_level_1()
    end
  end

  @spec get_goal_from_rx_value(number(), tuple()) :: number()
  def get_goal_from_rx_value(value, {output_min, output_mid, output_max, multiplier, deadband}) do
    value = ViaUtils.Math.apply_deadband(value, deadband)
    unscaled_value = multiplier * value

    if unscaled_value > 0 do
      output_mid + unscaled_value * (output_max - output_mid)
    else
      output_mid + unscaled_value * (output_mid - output_min)
    end
  end
end
