defmodule Via.Application do
  use Application
  require Logger

  def start(_type, _args) do
    prepare_environment()

    Logger.warn("Via.Application.Start")

    cond do
      is_target() ->
        Logger.warn("Sim environment. Start sim.")
        start_sim()

      Mix.env() != :test ->
        Logger.debug("Non-sim environment. Start vehicle.")
        node_type = System.get_env("node")

        if is_nil(node_type) or node_type == "Sim" do
          start_sim()
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

  @spec start_sim() :: atom()
  def start_sim() do
    input_type =
      System.get_env("input", "rx")
      |> String.downcase()

    case input_type do
      "" ->
        raise "Input not specified. Please add system argument input="

      "any" ->
        start_sim(:any)

      "keyboard" ->
        start_sim(:keyboard)

      "joystick" ->
        start_sim(:joystick)

      "rx" ->
        start_sim_rx(get_usb_converter_name())

      other ->
        raise "#{inspect(other)} not recognized. Input must be Joystick, Keyboard, Any, or Rx (case-insensitive). Please try again."
    end
  end

  @spec start_sim(atom()) :: atom()
  def start_sim(remote_control_interface) do
    full_config = Configuration.Utils.config("FixedWing", "Cessna", "Sim")

    simulation_config =
      full_config[:Simulation]
      |> Kernel.++(
        apply(Configuration.FixedWing.Cessna.Sim.Simulation, remote_control_interface, [])
      )

    full_config = Keyword.put(full_config, :Simulation, simulation_config)
    start_with_config(full_config)
  end

  @spec start_sim_rx(binary()) :: atom()
  def start_sim_rx(usb_converter \\ "CP2104") do
    uart_config = Configuration.FixedWing.Cessna.Sim.Uart.config(["CommandRx_" <> usb_converter])

    full_config =
      Configuration.Utils.config("FixedWing", "Cessna", "Sim")
      |> Keyword.put(:Uart, uart_config)

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
    # Logger.debug("full_config: #{inspect(full_config)}")
    Via.Supervisor.start_universal_modules(full_config)
    full_config
  end

  @spec start_test(binary()) :: keyword()
  def start_test(node_type \\ "Sim") do
    start_test("FixedWing", "Cessna", node_type)
  end

  @spec prepare_environment() :: atom()
  def prepare_environment() do
    # if Common.Utils.is_target?() do
    RingLogger.attach()
    # end
  end

  @spec is_target() :: boolean()
  def is_target() do
    String.contains?(File.cwd!(), "/srv/erlang")
  end

  @spec get_mix_env() :: binary()
  def get_mix_env() do
    System.get_env()
    |> Map.get("MIX_ENV", "")
  end
end
