defmodule Command.Commander do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups
  require Command.ControlTypes

  def start_link(config) do
    Logger.debug("Start Command.Commander GenServer")
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
      universal_channel_number_min_mid_max: universal_channel_number_min_mid_max,
      pilot_control_level_channel: pilot_control_level_channel,
      autopilot_control_mode_channel: autopilot_control_mode_channel
      # command_limits_min_mid_max: Keyword.fetch!(config, :command_limits_min_mid_max)
    }

    Comms.Supervisor.start_operator(__MODULE__)
    Comms.Operator.join_group(__MODULE__, Groups.command_channels_failsafe(), self())
    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({Groups.command_channels_failsafe(), channel_values, _failsafe_active}, state) do
    Logger.debug("Channel values: #{inspect(channel_values)}")
    channel_value_map = Stream.zip(0..(state.num_channels - 1), channel_values) |> Enum.into(%{})

    autopilot_control_mode =
      Map.fetch!(channel_value_map, state.autopilot_control_mode_channel)
      |> autopilot_control_mode_from_float()

    Logger.debug("acm: #{autopilot_control_mode}")

    if autopilot_control_mode != Command.ControlTypes.autopilot_control_mode_full_auto() do
      pilot_control_level =
        Map.fetch!(channel_value_map, state.pilot_control_level_channel)
        |> pilot_control_level_from_float()

      Logger.debug("pcl: #{pilot_control_level}")

      channels =
        Map.fetch!(state.control_level_dependent_channel_number_min_mid_max, pilot_control_level)
        |> Map.merge(state.universal_channel_number_min_mid_max)

      Logger.debug("channels: #{inspect(channels)}")

      commands =
        Enum.reduce(channels, %{}, fn {channel_name,
                                       {channel_number, output_min, output_mid, output_max,
                                        multiplier}},
                                      acc ->
          # Logger.debug(
          #   "ch num/min/max: #{channel_number}/#{ViaUtils.Format.eftb(output_min, 2)}/#{
          #     ViaUtils.Format.eftb(output_max, 2)
          #   }"
          # )

          unscaled_value = multiplier * Map.fetch!(channel_value_map, channel_number)

          scaled_value =
            if unscaled_value > 0 do
              output_mid + unscaled_value * (output_max - output_mid)
            else
              output_mid + unscaled_value * (output_mid - output_min)
            end

          Map.put(acc, channel_name, scaled_value)
        end)

      Logger.debug("cmds: #{ViaUtils.Format.eftb_map(commands, 3)}")

      {:noreply, state}
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
        Command.ControlTypes.pilot_control_level_speed_courserate_altituderate_sideslip()

      pcl_float > -0.5 ->
        Command.ControlTypes.pilot_control_level_roll_pitch_yawrate_throttle()

      true ->
        Command.ControlTypes.pilot_control_level_rollrate_pitchrate_yawrate_throttle()
    end
  end

  @spec get_command_for_min_mid_max_multiplier(number(), number(), number(), number(), number()) ::
          number()
  def get_command_for_min_mid_max_multiplier(
        value,
        output_min,
        output_mid,
        output_max,
        multiplier
      ) do
  end
end
