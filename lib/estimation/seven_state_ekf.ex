defmodule SevenStateEkf do
  use GenServer
  require Logger
  def start_link(config) do
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer, __MODULE__, config)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Logger.debug("Begin #{__MODULE__}: #{inspect(config)}")
    state = %{

    }
    {:noreply, state}
  end

end
