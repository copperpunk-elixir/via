defmodule MessageSorter.DiscreteLooper do
  require Logger
  alias MessageSorter.DiscreteLooper.Member, as: DLMember

  defstruct interval_ms: nil, members: %{}, time_ms: 0, name: nil

  @spec new(any(), integer()) :: struct()
  def new(name, interval_ms) do
    # Logger.info("Creating #{inspect(name)} DiscreteLooper with inteval: #{interval_ms}")

    %MessageSorter.DiscreteLooper{
      name: name,
      interval_ms: interval_ms,
      time_ms: 0,
      members: %{}
    }
  end

  @spec add_member_to_looper(struct(), any(), integer(), boolean()) :: struct()
  def add_member_to_looper(looper, pid, new_interval_ms, send_when_stale \\ true) do
    looper_interval_ms = looper.interval_ms

    members =
      if valid_interval?(new_interval_ms, looper_interval_ms) do
        members = looper.members
        # Logger.info("add #{inspect(pid)} to #{new_interval_ms}/#{send_when_stale} member list")
        # Logger.info("#{inspect(looper.name)} members: #{inspect(members)}")
        # Logger.debug("looper_interval: #{looper_interval_ms}")
        # num_intervals = round(1000 / looper_interval_ms)
        # Logger.info("num_ints: #{num_intervals}")
        Enum.reduce(looper_interval_ms..1000//looper_interval_ms, members, fn single_interval_ms,
                                                                              members_acc ->
          members_for_interval =
            if rem(single_interval_ms, new_interval_ms) == 0 do
              new_member = DLMember.new(pid, send_when_stale)
              [new_member] ++ Map.get(members, single_interval_ms, [])
            else
              Map.get(members, single_interval_ms, [])
            end

          if Enum.empty?(members_for_interval),
            do: members_acc,
            else: Map.put(members_acc, single_interval_ms, members_for_interval)
        end)
      else
        Logger.warn(
          "Add Members Interval #{new_interval_ms} is invalid: #{looper_interval_ms} for #{inspect(looper.name)}"
        )

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
        Logger.warn(
          "Update Members Interval #{interval_ms} is invalid for #{inspect(looper.name)}"
        )

        looper.members
      end

    %{looper | members: members}
  end

  @spec update_all_members(struct(), list()) :: struct()
  def update_all_members(looper, member_interval_list) do
    looper = reset(looper)

    Enum.reduce(member_interval_list, looper, fn {pid, {interval_ms, send_when_stale}}, acc ->
      add_member_to_looper(acc, pid, interval_ms, send_when_stale)
    end)
  end

  @spec step(struct()) :: struct()
  def step(looper) do
    %{time_ms: time_ms, interval_ms: interval_ms} = looper
    time_ms = time_ms + interval_ms
    time_ms = if time_ms > 1000, do: interval_ms, else: time_ms
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
    Enum.reduce(looper.members, [], fn {_interval, pid_list}, acc ->
      Enum.uniq(pid_list ++ acc)
    end)
  end

  @spec valid_interval?(integer(), integer()) :: boolean()
  def valid_interval?(desired_interval_ms, interval_ms) do
    rem(desired_interval_ms, interval_ms) == 0
  end

  @spec reset(struct()) :: struct()
  def reset(looper) do
    Logger.debug("reset #{inspect(looper.name)}")
    %{looper | members: %{}}
  end
end
