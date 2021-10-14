defmodule Display.Supervisor do
  # use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Display Supervisor")
    supervisor_module = Module.concat(config[:display_module], Supervisor)
    apply(supervisor_module, :start_link, [config])
    # ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  # def init(config) do
  #   children = [
  #     apply(config[:display_module], :child_spec, [Keyword.drop(config, [:display_module])])
  #   ]

  #   Supervisor.init(children, strategy: :one_for_one)
  # end
end
