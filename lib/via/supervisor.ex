defmodule Via.Supervisor do
  use DynamicSupervisor
  require Logger

  @spec start_universal_modules(keyword()) :: atom()
  def start_universal_modules(full_config) do
    Logger.debug("Via.Supervisor start universal modules")
    start_link()

    Process.sleep(200)
    start_module(MessageSorter, full_config[:MessageSorter])
    Process.sleep(200)
    start_module(Comms, full_config[:Comms])

    Process.sleep(200)
  end

  def start_link() do
    Logger.info("Start Via.Supervisor")
    UtilsProcess.start_link_redundant(DynamicSupervisor, __MODULE__, nil, __MODULE__)
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

  @spec start_module(module(), keyword()) :: atom()
  def start_module(module, config) do
    Logger.info("Via Starting Module: #{module} with config: #{inspect(config)}")

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
end
