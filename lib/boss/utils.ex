defmodule Boss.Utils do
  require Logger

  @spec get_config(atom(), binary(), binary()) :: map()
  def get_config(module, model_type, node_type) do
    module_atom = Module.concat(Configuration.Module, module)
    # Logger.debug("module atom: #{module_atom}")
    apply(module_atom, :get_config, [model_type, node_type])
  end

  @spec get_modules_for_node(binary()) :: list()
  def get_modules_for_node(node_type) do
    [node_type, _metadata] = Common.Utils.Configuration.split_safely(node_type, "_")

    case node_type do
      "gcs" ->
        [Display.Scenic, Peripherals.Uart, Gcs]

      "sim" ->
        [
          Estimation
        ]

      "server" ->
        [Simulation, Peripherals.Uart, Display.Scenic]

      "all" ->
        [
          Pids,
          Control,
          Estimation,
          Health,
          Navigation,
          Command,
          Peripherals.Uart,
          Peripherals.Gpio,
          Peripherals.I2c,
          Peripherals.Leds
        ]

      _vehicle ->
        [
          Pids,
          Control,
          Estimation,
          Health,
          Navigation,
          Command,
          Peripherals.Uart,
          Peripherals.Gpio,
          Peripherals.I2c,
          Peripherals.Leds
        ]
    end
  end
end
