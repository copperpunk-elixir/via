defmodule TestHelper.DiscreteLooper.GenServer do
  use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start DummyGenServer: #{inspect(config[:name])}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, via_tuple(config[:name]))
  end

  @impl GenServer
  def init(config) do
    {:ok, Keyword.drop(config, [:name])}
  end

  @impl GenServer
  def handle_cast({:join_registry, registry, key, value}, state) do
    Logger.debug("join registry: #{registry}/#{key}/#{value}: #{inspect(self())}")
    Registry.register(registry, key, value)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:timer, state) do
    Logger.debug("timer called")
    {:noreply, state}
  end

  def join_registry(name, registry, key, value \\ nil) do
    GenServer.cast(via_tuple(name), {:join_registry, registry, key, value})
  end

  def via_tuple(name) do
    ViaUtils.Registry.via_tuple(__MODULE__, name)
  end
end
