defmodule MessageSorter.DiscreteLooper.AddSubsTest do
  use ExUnit.Case
  require Logger
  alias TestHelper.DiscreteLooper.GenServer, as: DLG
  alias MessageSorter.DiscreteLooper

  setup do
    Via.Application.start_test()
    registry = MessageSorterRegistry
    ViaUtils.Process.start_link_redundant(Registry, Registry, keys: :duplicate, name: registry)
    {:ok, [registry: registry]}
  end

  test "add subs test", context do
    registry = context[:registry]
    key = :test
    interval = 50
    looper = DiscreteLooper.new_discrete_looper("looper", interval)
    sub1 = [name: "sub1", interval: 50]
    sub2 = [name: "sub2", interval: 200]
    {:ok, pid1} = DLG.start_link(sub1)
    {:ok, pid2} = DLG.start_link(sub2)
    DLG.join_registry(sub1[:name], registry, key, sub1[:interval])
    DLG.join_registry(sub2[:name], registry, key, sub2[:interval])
    Process.sleep(200)
    registry_members = Registry.lookup(registry, key)
    looper = DiscreteLooper.update_all_members(looper, registry_members)
    looper_members = DiscreteLooper.get_all_members_flat(looper)
    Logger.debug("#{inspect(looper_members)}")
    assert length(looper_members) == 2

    looper = DiscreteLooper.update_all_members(looper, [])
    looper_members = DiscreteLooper.get_all_members_flat(looper)
    Logger.debug("#{inspect(looper_members)}")
    assert length(looper_members) == 0

    Process.sleep(500)
  end
end
