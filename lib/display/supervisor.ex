defmodule Display.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Display Supervisor")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  def init(config) do
    children = [Supervisor.child_spec({Scenic, viewports: config[:viewports]}, id: :scenic_app)]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
