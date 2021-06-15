defmodule MessageSorter.DiscreteLooper do
  require Logger

  defstruct interval_ms: nil, members: %{}, time_ms: 0, name: nil

  @spec new_discrete_looper(any(), integer()) :: struct()
  def new_discrete_looper(name, interval_ms) do
    # Logger.info("Creating DiscreteLooper with inteval: #{interval_ms}")
    %MessageSorter.DiscreteLooper{
      name: name,
      interval_ms: interval_ms,
      time_ms: 0,
      members: %{}
    }
  end

  @spec add_member_to_looper(struct(), any(), integer()) :: struct()
  def add_member_to_looper(looper, pid, new_interval_ms) do
    looper_interval_ms = looper.interval_ms
    members =
    if valid_interval?(new_interval_ms, looper_interval_ms) do
      members = looper.members
      # Logger.info("add #{inspect(pid)} to #{new_interval_ms} member list")
      # Logger.info("members: #{inspect(members)}")
      # Logger.debug("looper_interval: #{looper_interval_ms}")
      num_intervals = round(1000/looper_interval_ms)
      # Logger.info("num_ints: #{num_intervals}")
      Enum.reduce(1..num_intervals, members, fn (mult, members_acc) ->
        single_interval_ms = mult*looper_interval_ms
        pids =
        if rem(single_interval_ms, new_interval_ms) == 0 do
          [pid] ++ Map.get(members, single_interval_ms, [])
        else
          Map.get(members, single_interval_ms, [])
        end
        if Enum.empty?(pids), do: members_acc, else: Map.put(members_acc, single_interval_ms, pids)
      end)
    else
      Logger.warn("Add Members Interval #{new_interval_ms} is invalid: #{looper_interval_ms} for #{inspect(looper.name)}")
      looper.members
    end
    # Logger.debug("#{inspect(looper.name)} updated all members: #{inspect(members)}")
    %{looper | members: members}
  end

  @spec update_members_for_interval(struct(), list(), integer()) :: struct()
  def update_members_for_interval(looper, new_member_list, interval_ms) do
    members =
    if valid_interval?(interval_ms, looper.interval_ms) do
      Map.put(looper.members, interval_ms, new_member_list)
    else
      Logger.warn("Update Members Interval #{interval_ms} is invalid for #{inspect(looper.name)}")
      looper.members
    end
    %{looper | members: members}
  end

  @spec update_all_members(struct(), list()) :: struct()
  def update_all_members(looper, member_interval_list) do
    looper = new_discrete_looper(looper.name, looper.interval_ms)
    Enum.reduce(member_interval_list, looper, fn ({pid, interval_ms}, acc) ->
      add_member_to_looper(acc, pid, interval_ms)
    end)
  end

  @spec step(struct()) :: struct()
  def step(looper) do
    time_ms = looper.time_ms + looper.interval_ms
    time_ms = if (time_ms > 1000), do: 0, else: time_ms
    %{looper | time_ms: time_ms}
  end

  @spec get_members_now(struct) :: list()
  def get_members_now(looper) do
    Map.get(looper.members, looper.time_ms, [])
  end

  @spec get_members_for_interval(struct(), integer()) :: list
  def get_members_for_interval(looper, interval_ms) do
    Map.get(looper.members, interval_ms, [])
  end

  @spec get_all_members_flat(struct()) :: list()
  def get_all_members_flat(looper) do
    Enum.reduce(looper.members, [], fn ({_interval, pid_list}, acc) ->
      Enum.uniq(pid_list ++ acc)
    end)
  end

  @spec valid_interval?(integer(), integer()) :: boolean()
  def valid_interval?(desired_interval_ms, interval_ms) do
    rem(desired_interval_ms, interval_ms) == 0
  end

end
