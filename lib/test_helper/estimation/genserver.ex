defmodule TestHelper.Estimation.GenServer do
  use GenServer
  require Logger
  require Comms.Groups, as: Groups

  def start_link() do
    Logger.debug("Start #{__MODULE__}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, nil)
  end

  @impl GenServer
  def init(_) do
    Comms.Supervisor.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude_dt(), self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_velocity_dt(),
      self()
    )

    state = %{
      attitude_rad: %{},
      position_velocity: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude_dt(), attitude_rad, _dt}, state) do
    {:noreply, %{state | attitude_rad: attitude_rad}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.estimation_position_velocity_dt(), position, velocity, _dt_s},
        state
      ) do
    {:noreply,
     %{
       state
       | position: position,
         velocity: velocity
     }}
  end

  @impl GenServer
  def handle_call({:get_value, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @spec get_value_for_key(atom()) :: any()
  def get_value_for_key(key) do
    GenServer.call(__MODULE__, {:get_value, key}, 1000)
  end
end
