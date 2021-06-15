defmodule Configuration.FixedWing.Cessna.Sim.Config do
  require Logger

  def config() do
    modules = [
      :Comms,
      :MessageSorter,
      :Estimation,
      :Uart
    ]

    IO.puts("modules: #{inspect(modules)}")

    Enum.reduce(modules, [], fn module, acc ->
      full_module_name = Module.concat(Configuration.FixedWing.Cessna.Sim, module)
      single_config = apply(full_module_name, :config, [])
      # IO.puts("config for module #{inspect(module)}: #{inspect(single_config)}")
      # IO.puts("full config so far: #{inspect(acc)}")
      Keyword.put(acc, module, single_config)
    end)
  end
end
