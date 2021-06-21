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
    ViaUtils.Comms.join_group(__MODULE__, Groups.estimation_attitude, self())

    ViaUtils.Comms.join_group(
      __MODULE__,
      Groups.estimation_position_speed_course_airspeed,
      self()
    )

    state = %{
      attitude_rad: nil,
      position_rrm: nil,
      speed_mps: nil,
      course_rad: nil,
      airspeed_mps: nil
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.estimation_attitude, attitude_rad, _dt}, state) do
    {:noreply, %{state | attitude_rad: attitude_rad}}
  end

  @impl GenServer
  def handle_cast(
        {Groups.estimation_position_speed_course_airspeed, position_rrm, speed_mps,
         course_rad, airspeed_mps, _dt},
        state
      ) do
    {:noreply,
     %{
       state
       | position_rrm: position_rrm,
         speed_mps: speed_mps,
         course_rad: course_rad,
         airspeed_mps: airspeed_mps
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
