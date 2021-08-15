defmodule Simulation.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Simulation modules (self-supervised)")

    # Enum.each(Keyword.drop(config, [:Interface]), fn {module_name, module_config} ->
    #   # Logger.debug("mod name/config: #{module_name}/#{inspect(module_config)}")
    #   apply(Module.concat([module_name]), :start_link, [module_config])
    # end)

    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    # {interface_config, _config} = Keyword.pop!(config, :Interface)
    children = Enum.reduce(config, [], fn {module_name, module_config}, acc ->
      # Logger.debug("mod name/config: #{module_name}/#{inspect(module_config)}")
      if module_name == :Interface do
        acc ++ [{Simulation.Interface, module_config}]
      else
        acc ++ [{Module.concat([module_name]), module_config}]
      end
      # apply(Module.concat([module_name]), :start_link, [module_config])
    end)


    # children = [{Simulation.Interface, interface_config}]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
