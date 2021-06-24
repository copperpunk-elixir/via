defmodule Via.Supervisor do
  use DynamicSupervisor
  require Logger

  @spec start_universal_modules(keyword()) :: atom()
  def start_universal_modules(full_config) do
    Logger.debug("Via.Supervisor start universal modules")
    start_link()

    start_supervised_process(ViaUtils.Registry, [])
    start_supervisor(Comms, full_config[:Comms])
    start_supervisor(MessageSorter, full_config[:MessageSorter])
  end

  def start_link() do
    Logger.info("Start Via.Supervisor")
    ViaUtils.Process.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
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

  @spec start_supervisor(atom(), keyword()) :: atom()
  def start_supervisor(module, config) do
    Logger.debug("Via Starting Module: #{module} with config: #{inspect(config)}")

    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: Module.concat(module, Supervisor),
        start: {
          Module.concat(module, Supervisor),
          :start_link,
          [config]
        }
      }
    )
  end

  @spec start_supervised_process(atom(), keyword()) :: atom()
  def start_supervised_process(module, config) do
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: module,
        start: {
          module,
          :start_link,
          [config]
        }
      }
    )
  end
end
