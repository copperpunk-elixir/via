defmodule MessageSorter.Sorter do
  use GenServer
  require Logger
  require Comms.MessageHeaders
  alias MessageSorter.DiscreteLooper
  # require MessageSorter.Sorter, as: Sorter

  @classification_length 2

  @message_sorter_registry MessageSorterRegistry
  @status_current :current_value
  @status_last :last_value
  @status_decay :decay_value
  @status_default :default_value
  @join_global_sorter_group :join_global_sorter_group

  defmacro registry(), do: @message_sorter_registry
  defmacro status_current(), do: @status_current
  defmacro status_last(), do: @status_last
  defmacro status_decay(), do: @status_decay
  defmacro status_default(), do: @status_default

  def start_link(config) do
    Logger.info("Start MessageSorter: #{inspect(config[:name])}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, via_tuple(config[:name]))
  end

  @impl GenServer
  def init(config) do
    name = config[:name]

    {default_message_behavior, default_value} =
      case Keyword.get(config, :default_message_behavior) do
        @status_last -> {@status_last, nil}
        @status_default -> {@status_default, config[@status_default]}
        @status_decay -> {@status_decay, config[@status_decay]}
      end

    publish_value_looper =
      case Keyword.get(config, :publish_value_interval_ms) do
        nil ->
          nil

        interval_ms ->
          ViaUtils.Process.start_loop(self(), interval_ms, {:publish_loop, :value})
          ViaUtils.Process.start_loop(self(), 1000, {:update_subscriber_loop, :value})
          DiscreteLooper.new({name, :value}, interval_ms)
      end

    publish_messages_looper =
      case Keyword.get(config, :publish_messages_interval_ms) do
        nil ->
          nil

        interval_ms ->
          ViaUtils.Process.start_loop(self(), interval_ms, {:publish_loop, :messages})
          ViaUtils.Process.start_loop(self(), 1000, {:update_subscriber_loop, :messages})
          DiscreteLooper.new({name, :messages}, interval_ms)
      end

    if !is_nil(Keyword.get(config, :global_sorter_group)) do
      ViaUtils.Comms.start_operator(name)
      GenServer.cast(via_tuple(name), {@join_global_sorter_group, config[:global_sorter_group]})
    end

    state = %{
      name: name,
      messages: [],
      last_value: Keyword.get(config, :initial_value, nil),
      default_message_behavior: default_message_behavior,
      default_value: default_value,
      value_type: Keyword.fetch!(config, :value_type),
      publish_loopers: %{value: publish_value_looper, messages: publish_messages_looper}
    }

    {:ok, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @spec register_for_sorter_current_only(any(), atom(), integer()) :: tuple()
  def register_for_sorter_current_only(sorter_name, value_or_messages, publish_interval_ms) do
    register_for_sorter(sorter_name, value_or_messages, publish_interval_ms, false)
  end

  @spec register_for_sorter_current_and_stale(any(), atom(), integer()) :: tuple()
  def register_for_sorter_current_and_stale(sorter_name, value_or_messages, publish_interval_ms) do
    register_for_sorter(sorter_name, value_or_messages, publish_interval_ms, true)
  end

  @spec register_for_sorter(any(), atom(), integer(), boolean()) :: tuple()
  def register_for_sorter(sorter_name, value_or_messages, publish_interval_ms, send_when_stale) do
    if value_or_messages == :message and !send_when_stale do
      raise ":messages sorters will always send values. They currently do not confirm that all messages are current."
    end

    Registry.register(
      @message_sorter_registry,
      {sorter_name, value_or_messages},
      {publish_interval_ms, send_when_stale}
    )
  end

  @impl GenServer
  def handle_cast({@join_global_sorter_group, group}, state) do
    Logger.warn("join global sorter group: #{inspect(group)}")
    ViaUtils.Comms.join_group(state.name, group, self())
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {Comms.MessageHeaders.global_group_to_sorter(), classification, time_validity_ms, value},
        state
      ) do
    expiration_mono_ms = get_expiration_mono_ms(time_validity_ms)
    messages = add_message_helper(classification, expiration_mono_ms, value, state)
    {:noreply, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_cast({:add_message, classification, expiration_mono_ms, value}, state) do
    messages = add_message_helper(classification, expiration_mono_ms, value, state)
    {:noreply, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_cast({:remove_message, classification}, state) do
    messages =
      if is_valid_classification?(classification) do
        # Remove any messages that have the same classification (there should be at most 1)
        Enum.reject(state.messages, &(&1.classification == classification))
      else
        state.messages
      end

    {:noreply, %{state | messages: messages}}
  end

  @impl GenServer
  def handle_cast(:remove_all_messages, state) do
    {:noreply, %{state | messages: []}}
  end

  @impl GenServer
  def handle_cast({:get_value_async, name, sender_pid}, state) do
    # Logger.warn("get value async: #{inspect(name)}/#{inspect(sender_pid)}")
    {state, classification, value, status} = get_current_value(state)
    GenServer.cast(sender_pid, {:message_sorter_value, name, classification, value, status})
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:publish_loop, :value}, state) do
    publish_looper = DiscreteLooper.step(state.publish_loopers.value)

    {state, classification, value, status} = get_current_value(state)
    name = state.name

    Enum.each(DiscreteLooper.get_members_now(publish_looper), fn member ->
      # Logger.debug("Send #{inspect(value)}/#{status} to #{inspect(name)}")

      if status == @status_current or member.send_when_stale do
        GenServer.cast(
          member.process_id,
          {:message_sorter_value, name, classification, value, status}
        )
      end
    end)

    publish_loopers = Map.put(state.publish_loopers, :value, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @impl GenServer
  def handle_info({:publish_loop, :messages}, state) do
    publish_looper = DiscreteLooper.step(state.publish_loopers.messages)
    messages = get_all_messages(state)
    name = state.name

    Enum.each(DiscreteLooper.get_members_now(publish_looper), fn dest ->
      # Logger.debug("Send #{inspect(value)}/#{status} to #{inspect(dest)}")
      GenServer.cast(dest, {:message_sorter_messages, name, messages})
    end)

    publish_loopers = Map.put(state.publish_loopers, :messages, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @impl GenServer
  def handle_info({:update_subscriber_loop, sub_type}, state) do
    subs = Registry.lookup(@message_sorter_registry, {state.name, sub_type})
    # Logger.info("subs: #{inspect(subs)}")
    # Logger.debug("sorter update members: #{inspect(state.name)}/#{sub_type}")
    # Logger.debug("pub looper pre: #{inspect(publish_looper)}")
    publish_looper =
      DiscreteLooper.update_all_members(Map.get(state.publish_loopers, sub_type), subs)

    # Logger.debug("pub looper post: #{inspect(publish_looper)}")
    publish_loopers = Map.put(state.publish_loopers, sub_type, publish_looper)
    {:noreply, %{state | publish_loopers: publish_loopers}}
  end

  @spec get_current_value(map()) :: any()
  def get_current_value(state) do
    messages = prune_old_messages(state.messages)
    msg = get_most_urgent_msg(messages)

    {classification, value, value_status} =
      if is_nil(msg) do
        case state.default_message_behavior do
          @status_last -> {nil, state.last_value, @status_last}
          @status_default -> {nil, state.default_value, @status_default}
        end
      else
        {msg.classification, msg.value, @status_current}
      end

    {%{state | messages: messages, last_value: value}, classification, value, value_status}
  end

  @spec get_all_messages(map()) :: list()
  def get_all_messages(state) do
    prune_old_messages(state.messages)
  end

  def add_message_helper(classification, expiration_mono_ms, value, state) do
    # Logger.debug("add #{inspect(value)} to sorter: #{inspect(state.name)}")
    if is_valid_classification?(classification) do
      # Remove any messages that have the same classification (there should be at most 1)
      if is_nil(value) or !is_valid_type?(value, state.value_type) do
        Logger.error("Sorter #{inspect(state.name)} add message rejected")
        state.messages
      else
        unique_msgs = Enum.reject(state.messages, &(&1.classification == classification))
        new_msg = MessageSorter.MsgStruct.create_msg(classification, expiration_mono_ms, value)
        [new_msg | unique_msgs]
      end
    else
      state.messages
    end
  end

  def add_message(name, classification, time_validity_ms, value) do
    # Logger.debug("MSG sorter: #{inspect(name)}. add message: #{inspect(value)}")
    expiration_mono_ms = get_expiration_mono_ms(time_validity_ms)
    GenServer.cast(via_tuple(name), {:add_message, classification, expiration_mono_ms, value})
  end

  def add_message(name, msg_struct) do
    GenServer.cast(
      via_tuple(name),
      {:add_message, msg_struct.classification, msg_struct.expiration_mono_ms, msg_struct.value}
    )
  end

  @spec get_value_async(any(), any()) :: atom()
  def get_value_async(name, sender_pid) do
    GenServer.cast(via_tuple(name), {:get_value_async, name, sender_pid})
  end

  def remove_messages_for_classification(name, classification) do
    Logger.debug("remove messages for #{name}/#{inspect(classification)} not implemented yet")
  end

  def remove_all_messages(name) do
    GenServer.cast(via_tuple(name), :remove_all_messages)
  end

  def is_valid_classification?(new_classification) do
    length(new_classification) == @classification_length and
      Enum.all?(new_classification, fn x -> is_integer(x) end)
  end

  def get_most_urgent_msg(msgs) do
    # Logger.debug("messages after pruning: #{inspect(valid_msgs)}")
    sorted_msgs = sort_msgs_by_classification(msgs)
    Enum.at(sorted_msgs, 0)
  end

  def prune_old_messages(msgs) do
    current_time_ms = :erlang.monotonic_time(:millisecond)
    Enum.reject(msgs, &(&1.expiration_mono_ms < current_time_ms))
  end

  defp sort_msgs_by_classification(msgs) do
    Enum.sort_by(msgs, & &1.classification)
  end

  def get_expiration_mono_ms(time_validity_ms) do
    :erlang.monotonic_time(:millisecond) + time_validity_ms
  end

  def via_tuple(name) do
    ViaUtils.Registry.via_tuple(__MODULE__, name)
  end

  defp is_valid_type?(value, desired_type) do
    case desired_type do
      :number -> is_number(value)
      :map -> is_map(value)
      :atom -> is_atom(value)
      :tuple -> is_tuple(value)
      _other -> false
    end
  end
end
