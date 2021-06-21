defmodule Comms.Supervisor do
  use DynamicSupervisor
  require Logger
  require MessageSorter.Sorter

  def start_link(_) do
    Logger.debug("Start Comms DynamicSupervisor")
    {:ok, pid} = ViaUtils.Process.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
    start_process_registry()
    start_message_sorter_registry()
    {:ok, pid}
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_process_registry() :: atom()
  def start_process_registry() do
    DynamicSupervisor.start_child(__MODULE__,%{id: :registry, start: {ViaUtils.Registry, :start_link,[]}})
  end

  @spec start_message_sorter_registry() :: atom()
  def start_message_sorter_registry() do
     child_spec = {Registry, [keys: :duplicate, name: MessageSorter.Sorter.registry()]}
    DynamicSupervisor.start_child(__MODULE__,child_spec)
  end

  @spec start_operator(atom(), integer()) :: atom()
  def start_operator(name, refresh_groups_loop_interval_ms \\ 100) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: name,
        start: {
          ViaUtils.Comms,
          :start_link,
          [
            [
              name: name,
              refresh_groups_loop_interval_ms: refresh_groups_loop_interval_ms
            ]
          ]}
      }
    )
  end
end
