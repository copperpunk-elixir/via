defmodule Simulation.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Simulation modules (self-supervised)")

    Enum.each(Keyword.drop(config, [:Interface]), fn {module_name, module_config} ->
      # Logger.debug("mod name/config: #{module_name}/#{inspect(module_config)}")
      apply(Module.concat([module_name]), :start_link, [module_config])
    end)

    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    {interface_config, _config} = Keyword.pop!(config, :Interface)
    children = [{Simulation.Interface, interface_config}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
