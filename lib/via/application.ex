defmodule Via.Application do
  use Application
  require Logger

  def start(_type, _args) do
    prepare_environment()

    Logger.warn("Via.Application.Start")

    cond do
      ViaUtils.File.target?() ->
        Logger.warn("Sim environment. Start sim_target.")

        ViaUtils.File.mount_usb_drive("sda1")
        start_sim_target()

      Mix.env() != :test ->
        Logger.debug("Non-sim environment. Start vehicle.")
        node_type = System.get_env("node")

        if is_nil(node_type) or node_type == "Sim" do
          start_sim_host()
        else
          start_real_vehicle()
        end

      true ->
        :ok
    end

    {:ok, self()}
  end

  @spec start_real_vehicle() :: atom()
  def start_real_vehicle() do
    node_type = System.get_env("node")
    vehicle_type = System.get_env("vehicle")
    model_type = System.get_env("model")
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

    full_config = Configuration.Utils.config(vehicle_type, model_type, node_type)
    start_with_config(full_config)
  end

  @spec start_sim_target() :: atom()
  def start_sim_target() do
    {simulator_type, model_type, input_type} =
      Simulation.Utils.get_simulation_env("xplane", "skyhawk", "any")

    vehicle_type = Simulation.Utils.get_vehicle_type(model_type)

    model_module =
      Module.concat(["Configuration", simulator_type, vehicle_type, model_type, "Sim"])

    start_sim(input_type, model_module)
  end

  @spec start_sim_host() :: atom()
  def start_sim_host() do
    simulator_type = get_simulation_type("xplane")
    model_type = get_model_type("skyhawk")
    input_type = get_input_type("any")

    vehicle_type = Simulation.Utils.get_vehicle_type(model_type)

    model_module =
      Module.concat(["Configuration", simulator_type, vehicle_type, model_type, "Sim"])

    start_sim(input_type, model_module)
  end

  @spec start_sim(binary(), atom()) :: atom()
  def start_sim(input_type, model_module) when input_type == "rx" do
    usb_converter = get_usb_converter_name()

    uart_config_module = Module.concat(model_module, Uart)
    uart_config = apply(uart_config_module, :config, ["CommandRx_" <> usb_converter])

    full_config =
      Configuration.Utils.config(Module.concat(model_module, Config))
      |> Keyword.put(:Uart, uart_config)

    start_with_config(full_config)
  end

  @spec start_sim(binary(), module()) :: atom()
  def start_sim(input_type, model_module) do
    input_type = String.to_atom(input_type)

    full_config = Configuration.Utils.config(Module.concat(model_module, Config))

    sim_config_module = Module.concat(model_module, Simulation)

    simulation_config =
      full_config[:Simulation]
      |> Kernel.++(apply(sim_config_module, input_type, []))

    full_config = Keyword.put(full_config, :Simulation, simulation_config)
    start_with_config(full_config)
  end

  def get_usb_converter_name() do
    usb_converter_type = System.get_env("USB")

    if is_nil(usb_converter_type) do
      Logger.warn("USB Converter not specified. Using default of CP2104")
      "CP2104"
    else
      usb_converter_type
    end
  end

  @spec start_with_config(list()) :: atom()
  def start_with_config(full_config) do
    Via.Supervisor.start_universal_modules(full_config)

    Enum.each(full_config, fn {module, config} ->
      supervisor_module = Module.concat(module, Supervisor)
      apply(supervisor_module, :start_link, [config])
    end)

    :ok
  end

  @spec start_test(binary(), binary(), binary()) :: keyword()
  def start_test(vehicle_type, model_type, node_type) do
    # prepare_environment()
    full_config = Configuration.Utils.config(vehicle_type, model_type, node_type)
    Logger.debug("full_config: #{inspect(full_config)}")
    Via.Supervisor.start_universal_modules(full_config)
    full_config
  end

  @spec start_test(binary()) :: keyword()
  def start_test(node_type \\ "Sim") do
    start_test("FixedWing", "XpSkyhawk", node_type)
  end

  @spec prepare_environment() :: atom()
  def prepare_environment() do
    RingLogger.attach()
  end

  @spec get_model_type(binary()) :: atom()
  def get_model_type(default_input) do
    System.get_env("model", default_input)
    |> String.capitalize()
  end

  @spec get_simulation_type(binary()) :: atom()
  def get_simulation_type(default_input) do
    System.get_env("simulation", default_input)
    |> String.capitalize()
  end

  @spec get_input_type(binary()) :: atom()
  def get_input_type(default_input) do
    System.get_env("input", default_input)
    |> String.downcase()
  end

  @spec get_mix_env() :: binary()
  def get_mix_env() do
    System.get_env()
    |> Map.get("MIX_ENV", "")
  end
end
