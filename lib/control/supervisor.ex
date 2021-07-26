defmodule Control.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Control Supervisor")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children = [
      {Control.Controller, config[:Controller]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
