defmodule Uart.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Uart Supervisor")
    UtilsProcess.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  @impl Supervisor
  def init(config) do
    node_type = Keyword.fetch!(config, :node_type)
    [node_type, _node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    all_peripherals = Common.Utils.Configuration.get_uart_peripherals(node_type)

    children =
      Enum.reduce(all_peripherals, [], fn peripheral, acc ->
        module = Module.concat(Uart, peripheral)
        [device, port] = String.split(peripheral, "_")
        # Logger.debug("module: #{module}")
        # Logger.info("config: #{inspect(single_config)}")
        acc ++ [{module, config}]
      end)

    Supervisor.init(children, strategy: :one_for_one)
  end
end
