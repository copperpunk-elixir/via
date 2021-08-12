defmodule Via.Application do
  use Application
  require Logger

  def start(_type, _args) do
    prepare_environment()

    unless Mix.env() == :test do
      vehicle_type = System.get_env("vehicle_type")
      model_type = System.get_env("model_type")
      node_type = System.get_env("node_type")
      Logger.debug("vehicle_type: #{vehicle_type}")
      Logger.debug("model_type: #{model_type}")
      Logger.debug("node_type: #{node_type}")

      {vehicle_type, model_type, node_type} =
        if is_nil(vehicle_type) or is_nil(model_type) or is_nil(node_type) do
          Logger.warn("Args not present. Must get from mounted USB device.")
          vehicle_type = Configuration.Utils.get_vehicle_type()
          model_type = Configuration.Utils.get_model_type()
          node_type = Configuration.Utils.get_node_type()
          {vehicle_type, model_type, node_type}
        else
          {vehicle_type, model_type, node_type}
        end

      full_config = Configuration.Utils.full_config(vehicle_type, model_type, node_type)
      Via.Supervisor.start_universal_modules(full_config)

      Enum.each(full_config, fn {module, config} ->
        supervisor_module = Module.concat(module, Supervisor)
        apply(supervisor_module, :start_link, [config])
      end)
    end

    {:ok, self()}
  end

  @spec start_test(binary(), binary(), binary()) :: keyword()
  def start_test(vehicle_type, model_type, node_type) do
    prepare_environment()
    full_config = Configuration.Utils.full_config(vehicle_type, model_type, node_type)
    # Logger.debug("full_config: #{inspect(full_config)}")
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
end
