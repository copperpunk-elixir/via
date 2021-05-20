defmodule Boss.System do
  use DynamicSupervisor
  require Logger

  @spec start_universal_modules(binary(), binary()) :: atom()
  def start_universal_modules(model_type, node_type) do
    Logger.debug("Boss.System start universal modules")
    start_link()
    DynamicSupervisor.start_child(__MODULE__,%{id: Boss.Operator.Supervisor, start: {Boss.Operator, :start_link,[model_type, node_type]}})
    Process.sleep(200)
    start_module(Comms, model_type, node_type)
    Process.sleep(200)
    start_module(MessageSorter, model_type, node_type)
    Process.sleep(200)
  end

  def start_link() do
    Logger.info("Start Boss Supervisor")
    Common.Utils.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
  end

  @spec init(any) ::
          {:ok,
           %{
             extra_arguments: list,
             intensity: non_neg_integer,
             max_children: :infinity | non_neg_integer,
             period: pos_integer,
             strategy: :one_for_one
           }}
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec start_module(atom(), binary(), binary()) :: atom()
  def start_module(module, model_type, node_type) do
    Logger.info("Boss Starting Module: #{module}")
    config = Boss.Utils.get_config(module, model_type, node_type)
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: Module.concat(module, Supervisor),
        start: {
          Module.concat(module, System),
          :start_link,
          [config]
        }
      }
    )
  end

  @spec start_modules(list(), binary(), binary()) :: atom()
  def start_modules(modules, model_type, node_type) do
    Enum.each(modules, fn module ->
      start_module(module, model_type, node_type)
    end)
  end
end
