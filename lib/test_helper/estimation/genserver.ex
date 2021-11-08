defmodule TestHelper.Estimation.GenServer do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN

  def start_link() do
    Logger.debug("Start #{__MODULE__}")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, nil)
  end

  @impl GenServer
  def init(_) do
    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude_attrate_val(), self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_velocity_val(),
      self()
    )

    state = %{
      attitude_rad: %{},
      position_velocity: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude_attrate_val(), values}, state) do
    attitude_rad = Map.take(values, [SVN.roll_rad(), SVN.pitch_rad(), SVN.yaw_rad()])
    {:noreply, %{state | attitude_rad: attitude_rad}}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_position_velocity_val(), values}, state) do
    %{SVN.position_rrm() => position_rrm, SVN.velocity_mps() => velocity_mps} = values

    {:noreply,
     %{
       state
       | position: position_rrm,
         velocity: velocity_mps
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
