defmodule Common.DiscreteLooper.AddSubsTest do
  use ExUnit.Case
  require Logger
  alias Common.DiscreteLooper

  setup do
        {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}

    registry = MessageSorterRegistry
    UtilsProcess.start_link_redundant(Registry, Registry, [keys: :duplicate, name: registry])
    {:ok, [registry: registry]}
  end

  test "add subs test", context do
    registry = context[:registry]
    key = :test
    interval = 50
    looper = DiscreteLooper.new(interval)
    sub1 = [name: "sub1", interval: 50]
    sub2 = [name: "sub2", interval: 200]
    {:ok, pid1} = Workshop.DummyGenserver.start_link(sub1)
    {:ok, pid2} = Workshop.DummyGenserver.start_link(sub2)
    Workshop.DummyGenserver.join_registry(sub1[:name], registry, key, sub1[:interval])
    Workshop.DummyGenserver.join_registry(sub2[:name], registry, key, sub2[:interval])
    Process.sleep(200)
    registry_members = Registry.lookup(registry, key)
    looper = DiscreteLooper.update_all_members(looper,  registry_members)
    looper_members = DiscreteLooper.get_all_members_flat(looper)
    Logger.debug("#{inspect(looper_members)}")
    assert length(looper_members) == 2

    looper = DiscreteLooper.update_all_members(looper,  [])
    looper_members = DiscreteLooper.get_all_members_flat(looper)
    Logger.debug("#{inspect(looper_members)}")
    assert length(looper_members) == 0

    Process.sleep(500)
  end
end
