defmodule Configuration.FixedWing.Cessna.Sim.Uart do
  require Logger
  require ViaUtils.Constants, as: VC

  @spec config() :: list()
  def config() do
    # Logger.warn("uart node type: #{node_type}")
    peripherals = Configuration.Utils.get_uart_peripherals("Sim")
    # peripherals = ["Gps_u-blox", "Companion_Pico"]
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
        "0" -> "ttyAMA0"
        "3" -> "ttyAMA1"
        "4" -> "ttyAMA2"
        "5" -> "ttyAMA3"
        _usb -> port
      end

    [device, metadata] =
      case String.split(device, "-") do
        [dev] -> [dev, ""]
        [dev, meta] -> [dev, meta]
        _other -> raise "Device name improper format"
      end

    # Logger.debug("device/meta: #{device}/#{metadata}")
    case device do
      "Companion" -> {:Companion, get_companion_config(uart_port)}
      "Gps" -> {:Gps, get_gps_config(uart_port)}
      "Dsm" -> {:CommandRx, get_dsm_rx_config(uart_port)}
      "FrskyRx" -> {:CommandRx, get_frsky_rx_config(uart_port)}
      "TerarangerEvo" -> {:TerarangerEvo, get_teraranger_evo_config(uart_port)}
      "Telemetry" -> {:Telemetry, get_telemetry_config(uart_port)}
      "PwmReader" -> {:PwmReader, get_pwm_reader_config(uart_port)}
      "Generic" -> {:Generic, get_generic_config(uart_port, metadata)}
    end
  end

  @spec get_companion_config(binary()) :: list()
  def get_companion_config(uart_port) do
    [
      uart_port: uart_port, # usually Pico
      port_options: [speed: 115_200],
      accel_counts_to_mpss: VC.gravity() / 8192,
      gyro_counts_to_rps: VC.deg2rad() / 16.4
    ]
  end

  @spec get_gps_config(binary()) :: list()
  def get_gps_config(uart_port) do
    [
      uart_port: uart_port, # usually u-blox
      port_options: [speed: 115_200],
      gps_expected_antenna_distance_mm: 18225,
      gps_antenna_distance_error_threshold_mm: 200
    ]
  end

  @spec get_dsm_rx_config(binary()) :: list()
  def get_dsm_rx_config(uart_port) do
    [
      uart_port: uart_port, # usually CP2104
      rx_module: :Dsm,
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_frsky_rx_config(binary()) :: list()
  def get_frsky_rx_config(uart_port) do
    [
      uart_port: uart_port, # usually CP2104
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
      uart_port: uart_port, #expected FT232R
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_telemetry_config(binary()) :: list()
  def get_telemetry_config(uart_port) do
    [
      uart_port: uart_port, # SiK or Xbee: FT231X
      port_options: [speed: 57_600],
      fast_loop_interval_ms: Configuration.Generic.loop_interval_ms(:fast),
      medium_loop_interval_ms: Configuration.Generic.loop_interval_ms(:medium),
      slow_loop_interval_ms: Configuration.Generic.loop_interval_ms(:slow)
    ]
  end

  @spec get_pwm_reader_config(binary()) :: list()
  def get_pwm_reader_config(uart_port) do
    [
      uart_port: uart_port,
      port_options: [speed: 115_200]
    ]
  end

  @spec get_generic_config(binary(), binary()) :: list()
  def get_generic_config(uart_port, device_capability) do
    sorter_classification =
      Configuration.Generic.generic_peripheral_classification(device_capability)

    [
      uart_port: uart_port,
      port_options: [speed: 115_200],
      sorter_classification: sorter_classification
    ]
  end
end
