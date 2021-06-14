defmodule Via.Application do
  use Application
  require Logger

  def start(_type, _args) do
    vehicle_type = "FixedWing"
    model_type = "Cessna"
    node_type = "Sim"
    prepare_environment()

    full_config = Common.Utils.Configuration.full_config(vehicle_type, model_type, node_type)
    Via.Supervisor.start_universal_modules(full_config)
    Enum.each(full_config, fn {module, config} ->
      supervisor_module = Module.concat(module, Supervisor)
      # config = Via.Utils.get_config(module, model_type, node_type)
      apply(supervisor_module, :start_link, [config])
    end)

    {:ok, self()}
  end

  @spec start_test(binary(), binary(), binary()) :: keyword()
  def start_test(vehicle_type, model_type, node_type) do
    prepare_environment()
    full_config = Common.Utils.Configuration.full_config(vehicle_type, model_type, node_type)
    IO.puts("full_config: #{inspect(full_config)}")
    # IO.puts("Full config: #{inspect(full_config)}")
    Via.Supervisor.start_universal_modules(full_config)
    full_config
  end

  @spec start_test() :: keyword()
  def start_test() do
    start_test("FixedWing", "Cessna", "Sim")
  end

  @spec prepare_environment() :: atom()
  def prepare_environment() do
    # if Common.Utils.is_target?() do
    RingLogger.attach()
    # end
  end

  # @spec get_modules_for_node(binary()) :: list()
  # def get_modules_for_node(node_type) do
  #   [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")

  #   case node_type do
  #     "gcs" ->
  #       [Display.Scenic, Peripherals.Uart, Gcs]

  #     "sim" ->
  #       [
  #         Estimation,
  #         Peripherals.Uart
  #       ]

  #     "server" ->
  #       [Simulation, Peripherals.Uart, Display.Scenic]

  #     "all" ->
  #       [
  #         Pids,
  #         Control,
  #         Estimation,
  #         Health,
  #         Navigation,
  #         Command,
  #         Peripherals.Uart,
  #         Peripherals.Gpio,
  #         Peripherals.I2c,
  #         Peripherals.Leds
  #       ]

  #     _vehicle ->
  #       [
  #         Pids,
  #         Control,
  #         Estimation,
  #         Health,
  #         Navigation,
  #         Command,
  #         Peripherals.Uart,
  #         Peripherals.Gpio,
  #         Peripherals.I2c,
  #         Peripherals.Leds
  #       ]
  #   end
  # end
end
