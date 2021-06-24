defmodule Command.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Command Supervisor")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Command.Commander, config[:Commander]},
        {Command.RemotePilot, config[:RemotePilot]}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
