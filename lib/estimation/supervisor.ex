defmodule Estimation.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Estimation Supervisor")
    UtilsProcess.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      [
        {Estimation.Estimator, config[:estimator]}
      ]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
