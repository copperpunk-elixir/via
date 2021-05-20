defmodule MessageSorter.System do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start MessageSorter Supervisor")
    Common.Utils.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = get_all_children(config[:sorter_configs])
    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec get_all_children(list()) :: list()
  def get_all_children(sorter_configs) do
    Enum.reduce(sorter_configs, [], fn (config, acc) ->
      [Supervisor.child_spec({MessageSorter.Sorter, config}, id: config[:name])] ++ acc
    end)
  end
end
