defmodule Simulation.Supervisor do
  # use GenServer
  require Logger

  def start_link(config) do
    Logger.debug("Start Simulation modules (self-supervised)")
    Enum.each(config, fn {module_name, module_config} ->
      # Logger.debug("mod name/config: #{module_name}/#{inspect(module_config)}")
      apply(Module.concat([module_name]), :start_link, [module_config])
    end)

    # ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

end
