defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  require Common.Constants, as: CC

  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, node_type) do
    # subdirectory = Atom.to_string(node_type)
    [node_type, _node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    # Logger.warn("uart node type: #{node_type}")
    peripherals = Common.Utils.Configuration.get_uart_peripherals(node_type)
    Logger.debug("peripherals: #{inspect(peripherals)}")

    Enum.reduce(peripherals, [], fn peripheral, acc ->
      # peripheral_string = Atom.to_string(name)
      [device, port] = String.split(peripheral, "_")
      {module_key, module_config} = get_module_key_and_config(device, port)
      Keyword.put(acc, module_key, module_config)
    end)
  end

  @spec get_module_key_and_config(binary(), binary()) :: tuple()
  def get_module_key_and_config(device, port) do
    # Logger.debug("port: #{port}")
    uart_port =
      case port do
        "usb" -> "usb"
        # "0" -> "ttyS0"
        "0" -> "ttyAMA0"
        port_num -> "ttyAMA#{String.to_integer(port_num) - 2}"
      end

    [device, metadata] =
      case String.split(device, "-") do
        [dev] -> [dev, ""]
        [dev, meta] -> [dev, meta]
        _other -> raise "Device name improper format"
      end

    # Logger.debug("device/meta: #{device}/#{metadata}")
    case device do
      "Companion" -> {Companion, get_companion_config(uart_port)}
      "Gps" -> {Gps, get_gps_config(uart_port)}
      "Dsm" -> {Command.Rx, get_dsm_rx_config(uart_port)}
      "FrskyRx" -> {Command.Rx, get_frsky_rx_config(uart_port)}
      "TerarangerEvo" -> {Estimation.TerarangerEvo, get_teraranger_evo_config(uart_port)}
      "Telemetry" -> {Telemetry, get_telemetry_config(uart_port)}
      "PwmReader" -> {PwmReader, get_pwm_reader_config(uart_port)}
      "Generic" -> {Generic, get_generic_config(uart_port, metadata)}
    end
  end

  @spec get_companion_config(binary(), binary()) :: list()
  def get_companion_config(uart_port, usb_name \\ "Pico") do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, usb_name),
      port_options: [speed: 115_200],
      accel_counts_to_mpss: CC.gravity() / 8192,
      gyro_counts_to_rps: CC.deg2rad() / 16.4
    ]
  end

  @spec get_gps_config(binary(), binary()) :: list()
  def get_gps_config(uart_port, usb_name \\ "u-blox") do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, usb_name),
      port_options: [speed: 115_200],
      gps_expected_antenna_distance_mm: 18225,
      gps_antenna_distance_error_threshold_mm: 200,

    ]
  end

  @spec get_dsm_rx_config(binary()) :: list()
  def get_dsm_rx_config(uart_port) do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "CP2104"),
      rx_module: :Dsm,
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_frsky_rx_config(binary()) :: list()
  def get_frsky_rx_config(uart_port) do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "CP2104"),
      rx_module: :Frsky,
      port_options: [
        speed: 100_000,
        stop_bits: 2,
        parity: :even
      ]
    ]
  end

  @spec get_teraranger_evo_config(binary()) :: list()
  def get_teraranger_evo_config(uart_port) do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "FT232R"),
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_telemetry_config(binary()) :: list()
  def get_telemetry_config(uart_port) do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "FT231X"),
      port_options: [speed: 57_600],
      fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow)
    ]
  end

  @spec get_pwm_reader_config(binary()) :: list()
  def get_pwm_reader_config(uart_port) do
    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "Feather M0"),
      port_options: [speed: 115_200]
    ]
  end

  @spec get_generic_config(binary(), binary()) :: list()
  def get_generic_config(uart_port, device_capability) do
    sorter_classification =
      Configuration.Generic.generic_peripheral_classification(device_capability)

    [
      uart_port: get_port_name_gpio_or_usb(uart_port, "USB Serial"),
      port_options: [speed: 115_200],
      sorter_classification: sorter_classification
    ]
  end

  @spec get_port_name_gpio_or_usb(binary(), binary()) :: binary()
  def get_port_name_gpio_or_usb(uart_port, usb_device_name) do
    if uart_port == "usb", do: usb_device_name, else: uart_port
  end
end
