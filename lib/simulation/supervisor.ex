defmodule Simulation.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Simulation modules (self-supervised)")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    # Logger.info("config: #{inspect(config)}")
    children =
      Enum.reduce(config, [], fn {_name, module_config}, acc ->
        # Logger.debug("mod name/config: #{module_name}/#{inspect(module_config)}")
        {module_name, module_config} = pop_in(module_config, [:module])

        acc ++ [{Module.concat([module_name]), module_config}]
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
