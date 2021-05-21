defmodule Ubx.Utils.Test do
  require Ubx.MessageDefs
  require Logger
  use GenServer

  def start_link(config) do
    Logger.debug("Start Ubx.Utils.Test")
    Logger.debug("config: #{inspect(config)}")

    {:ok, process_id} = Common.Utils.start_link_redundant(GenServer, __MODULE__, nil)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, process_id}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Comms.System.start_operator(__MODULE__)

    Enum.each(Keyword.get(config, :groups, []), fn group ->
      Comms.Operator.join_group(__MODULE__, group, self())
    end)
    state = %{
      fwd_destination: Keyword.fetch!(config, :destination)
    }

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({group, msg}, state) when group != :begin do
    Logger.debug("#{__MODULE__} rx'd #{inspect(group)} msg: #{inspect(msg)}")
    send(state.fwd_destination, {group, msg})
    {:noreply, state}
  end

  def build_message(message_type, values) do
    apply(__MODULE__, message_type, values)
  end

  def accel_gyro_val(dt, ax, ay, az, gx, gy, gz) do
    {class, id} = Ubx.MessageDefs.accel_gyro_val_class_id()
    bytes = Ubx.MessageDefs.accel_gyro_val_bytes()
    values = [dt, ax, ay, az, gx, gy, gz]
    Ubx.Utils.construct_message(class, id, bytes, values)
  end
end
