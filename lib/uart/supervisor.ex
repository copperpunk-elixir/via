defmodule Uart.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Uart Supervisor with config #{inspect(config)}")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    children =
      Enum.reduce(config, [], fn {peripheral, single_config}, acc ->
        module = Module.concat(Uart, peripheral)
        # [device, port] = String.split(peripheral, "_")
        Logger.debug("module: #{module}")
        # Logger.info("config: #{inspect(single_config)}")
        acc ++ [{module, single_config}]
      end)

    # Logger.debug("kids: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_one)
  end
end
