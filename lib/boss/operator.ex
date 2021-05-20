defmodule Boss.Operator do
  use GenServer
  require Logger

  def start_link(model_type, node_type) do
    Logger.debug("Start Boss.Operator")
    {:ok, pid} = Common.Utils.start_link_singular(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, model_type, node_type})
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

  @impl GenServer
  def handle_cast({:begin, model_type, node_type}, _state) do
    state = %{
      model_type: model_type,
      node_type: node_type
    }
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:start_node_processes, state) do
    Logger.info("Boss Operator start_node_processes")
    model_type = state.model_type
    node_type = state.node_type
    Logger.debug("Start remaining processes for #{model_type}/#{node_type}")
    modules = Boss.Utils.get_modules_for_node(node_type)
    Boss.System.start_modules(modules, model_type, node_type)
    {:noreply, state}
  end

  @spec start_node_processes() :: atom()
  def start_node_processes do
    GenServer.cast(__MODULE__, :start_node_processes)
  end
end
