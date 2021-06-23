defmodule Command.RemotePilot do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Comms.MessageHeaders, as: MessageHeaders
  require Command.ControlTypes

  def start_link(config) do
    Logger.debug("Start Command.RemotePilot GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    universal_channel_number_min_mid_max =
      Keyword.fetch!(config, :universal_channel_number_min_mid_max)

    pilot_control_level_channel =
      Map.fetch!(universal_channel_number_min_mid_max, :pilot_control_level) |> elem(0)

    autopilot_control_mode_channel =
      Map.fetch!(universal_channel_number_min_mid_max, :autopilot_control_mode) |> elem(0)

    universal_channel_number_min_mid_max =
      Map.drop(universal_channel_number_min_mid_max, [
        :pilot_control_level,
        :autopilot_control_mode
      ])

    state = %{
      num_channels: Keyword.fetch!(config, :num_channels),
      control_level_dependent_channel_number_min_mid_max:
        Keyword.fetch!(config, :control_level_dependent_channel_number_min_mid_max),
      remote_pilot_override_channels: Keyword.fetch!(config, :remote_pilot_override_channels),
      universal_channel_number_min_mid_max: universal_channel_number_min_mid_max,
      pilot_control_level_channel: pilot_control_level_channel,
      autopilot_control_mode_channel: autopilot_control_mode_channel,
      goals_sorter_classification_and_time_validity_ms:
        Keyword.fetch!(config, :goals_sorter_classification_and_time_validity_ms)
      # command_limits_min_mid_max: Keyword.fetch!(config, :command_limits_min_mid_max)
    }

    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.command_channels_failsafe(), self())
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.command_channels_failsafe(), channel_values, _failsafe_active}, state) do
    # Logger.debug("Channel values: #{inspect(channel_values)}")
    channel_value_map = Stream.zip(0..(state.num_channels - 1), channel_values) |> Enum.into(%{})

    autopilot_control_mode =
      Map.fetch!(channel_value_map, state.autopilot_control_mode_channel)
      |> autopilot_control_mode_from_float()

    # Logger.debug("acm: #{autopilot_control_mode}")

    cond do
      autopilot_control_mode == Command.ControlTypes.autopilot_control_mode_controller_assist() ->
        pilot_control_level =
          Map.fetch!(channel_value_map, state.pilot_control_level_channel)
          |> pilot_control_level_from_float()

        # Logger.debug("pcl: #{pilot_control_level}")

        channels =
          Map.fetch!(
            state.control_level_dependent_channel_number_min_mid_max,
            pilot_control_level
          )
          |> Map.merge(state.universal_channel_number_min_mid_max)

        # Logger.debug("channels: #{inspect(channels)}")

        commands =
          Enum.reduce(channels, %{}, fn {channel_name,
                                         {channel_number, output_min, output_mid, output_max,
                                          multiplier, deadband}},
                                        acc ->
            output =
              get_command_for_min_mid_max_multiplier_deadband(
                Map.fetch!(channel_value_map, channel_number),
                output_min,
                output_mid,
                output_max,
                multiplier,
                deadband
              )

            Map.put(acc, channel_name, output)
          end)

        # Logger.debug("cmds: #{ViaUtils.Format.eftb_map(commands, 3)}")
        {goals_sorter_classification, goals_sorter_time_validity_ms} =
          state.goals_sorter_classification_and_time_validity_ms

        ViaUtils.Comms.send_global_msg_to_group(
          __MODULE__,
          {MessageHeaders.global_group_to_sorter(), Groups.pilot_control_level_and_goals_sorter, goals_sorter_classification,
           goals_sorter_time_validity_ms, {pilot_control_level, commands}},
          Groups.pilot_control_level_and_goals_sorter(),
          self()
        )

      autopilot_control_mode == Command.ControlTypes.autopilot_control_mode_disengaged() ->
        commands =
          Enum.reduce(state.remote_pilot_override_channels, %{}, fn {channel_name, channel_number},
                                                                    acc ->
            Map.put(acc, channel_name, Map.fetch!(channel_value_map, channel_number))
          end)

        {_classification, override_time_validity_ms} =
          state.goals_sorter_classification_and_time_validity_ms

        ViaUtils.Comms.send_global_msg_to_group(
          __MODULE__,
          {Groups.remote_pilot_goals_override(), commands, override_time_validity_ms},
          self()
        )

      true ->
        :ok
    end

    {:noreply, state}
  end

  @spec autopilot_control_mode_from_float(float()) :: integer()
  def autopilot_control_mode_from_float(acm_float) do
    cond do
      acm_float > 0.5 -> Command.ControlTypes.autopilot_control_mode_disengaged()
      acm_float > -0.5 -> Command.ControlTypes.autopilot_control_mode_controller_assist()
      true -> Command.ControlTypes.autopilot_control_mode_full_auto()
    end
  end

  @spec pilot_control_level_from_float(float()) :: integer()
  def pilot_control_level_from_float(pcl_float) do
    cond do
      pcl_float > 0.5 ->
        Command.ControlTypes.pilot_control_level_4()

      pcl_float > -0.5 ->
        Command.ControlTypes.pilot_control_level_2()

      true ->
        Command.ControlTypes.pilot_control_level_1()
    end
  end

  @spec get_command_for_min_mid_max_multiplier_deadband(
          number(),
          number(),
          number(),
          number(),
          number(),
          number()
        ) ::
          number()
  def get_command_for_min_mid_max_multiplier_deadband(
        value,
        output_min,
        output_mid,
        output_max,
        multiplier,
        deadband
      ) do
    value = ViaUtils.Math.apply_deadband(value, deadband)
    unscaled_value = multiplier * value

    if unscaled_value > 0 do
      output_mid + unscaled_value * (output_max - output_mid)
    else
      output_mid + unscaled_value * (output_mid - output_min)
    end
  end
end
