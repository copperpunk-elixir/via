defmodule Comms.Operator do
  use GenServer
  require Logger

  def start_link(config) do
    name = Keyword.fetch!(config, :name)
    Logger.debug("Start Comms.Operator: #{inspect(name)}")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, via_tuple(name))
    GenServer.cast(via_tuple(name), {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  def handle_cast({:begin, config}, _state) do
    state = %{
      refresh_groups_timer: nil,
      groups: %{},
      name: Keyword.fetch!(config, :name) #purely for dianostics
    }
    Common.Utils.start_loop(self(), Keyword.fetch!(config, :refresh_groups_loop_interval_ms), :refresh_groups)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:join_group, group, process_id}, state) do
    # We will be added to our own record of the group during the
    # :refresh_groups cycle
    # Logger.warn("#{inspect(state.name)} is joining group: #{inspect(group)}")
    :pg2.create(group)
    if !is_in_group?(group, process_id) do
      :pg2.join(group, process_id)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:leave_group, group, process_id}, state) do
    # We will be remove from our own record of the group during the
    # :refresh_groups cycle
    if is_in_group?(group, process_id) do
      :pg2.leave(group, process_id)
    end
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:send_msg_to_group, message, group, sender, global_or_local}, state) do
    # Logger.debug("send_msg. group: #{inspect(group)}")
    group_members = get_group_members(state.groups, group, global_or_local)
    # Logger.debug("Group members: #{inspect(group_members)}")
    send_msg_to_group_members(message, group_members, sender)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:refresh_groups, state) do
    groups =
      Enum.reduce(:pg2.which_groups, %{}, fn (group, acc) ->
        all_group_members = :pg2.get_members(group)
        local_group_members = :pg2.get_local_members(group)
        Map.put(acc, group, %{global: all_group_members, local: local_group_members})
      end)
    # Logger.debug("#{inspect(state.name)} groups after refresh: #{inspect(groups)}")
    {:noreply, %{state | groups: groups}}
  end

  def join_group(operator_name, group, process_id) do
    GenServer.cast(via_tuple(operator_name), {:join_group, group, process_id})
  end

  def leave_group(operator_name, group, process_id) do
    GenServer.cast(via_tuple(operator_name), {:leave_group, group, process_id})
  end

  @spec send_local_msg_to_group(atom(), any(), any(), any()) :: atom()
  def send_local_msg_to_group(operator_name, message, group, sender) do
    GenServer.cast(via_tuple(operator_name), {:send_msg_to_group, message, group, sender, :local})
  end

  @spec send_local_msg_to_group(atom(), tuple(), any()) :: atom()
  def send_local_msg_to_group(operator_name, message, sender) do
    # Logger.debug("send to group: #{elem(message, 0)}: #{inspect(message)}")
    GenServer.cast(via_tuple(operator_name), {:send_msg_to_group, message, elem(message,0), sender, :local})
  end

  @spec send_global_msg_to_group(atom(), any(), any(), any()) :: atom()
  def send_global_msg_to_group(operator_name, message, group, sender) do
    # Logger.debug("send global: #{inspect(message)}")
    GenServer.cast(via_tuple(operator_name), {:send_msg_to_group, message, group, sender, :global})
  end

  @spec send_global_msg_to_group(atom(), tuple(), any()) :: atom()
  def send_global_msg_to_group(operator_name, message, sender) do
    # Logger.debug("send global: #{inspect(message)}")
    GenServer.cast(via_tuple(operator_name), {:send_msg_to_group, message, elem(message,0), sender, :global})
  end

  defp send_msg_to_group_members(message, group_members, sender) do
    Enum.each(group_members, fn dest ->
      if dest != sender do
        # Logger.debug("Send #{inspect(message)} to #{inspect(dest)}")
        GenServer.cast(dest, message)
      end
    end)
  end

  def is_in_group?(group, pid) do
    members =
      case :pg2.get_members(group) do
        {:error, _} -> []
        members -> members
      end
    Enum.member?(members, pid)
  end

  def get_group_members(groups, group, global_or_local) do
    Map.get(groups, group, %{})
    |> Map.get(global_or_local, [])
  end

  def via_tuple(name) do
    Comms.ProcessRegistry.via_tuple(__MODULE__,name)
  end
end
