defmodule Configuration.Module.Peripherals.Uart do
  require Logger
  require Common.Constants

  @spec get_config(atom(), atom()) :: list()
  def get_config(_model_type, node_type) do
    # subdirectory = Atom.to_string(node_type)
    [node_type, _node_metadata] = Common.Utils.Configuration.split_safely(node_type, "_")
    # Logger.warn("uart node type: #{node_type}")
    peripherals = Common.Utils.Configuration.get_uart_peripherals(node_type)
    Logger.debug("peripherals: #{inspect(peripherals)}")
    Enum.reduce(peripherals, [], fn (peripheral, acc) ->
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
        port_num -> "ttyAMA#{String.to_integer(port_num)-2}"
      end
    [device, metadata] =
      case String.split(device, "-") do
        [dev] -> [dev, ""]
        [dev, meta] -> [dev, meta]
        _other -> raise "Device name improper format"
      end
    # Logger.debug("device/meta: #{device}/#{metadata}")
    case device do
      "Dsm" -> {Command.Rx, get_dsm_rx_config(uart_port)}
      "FrskyRx" -> {Command.Rx, get_frsky_rx_config(uart_port)}
      "FrskyServo" -> {Actuation, get_actuation_config(device, uart_port)}
      "PololuServo" -> {Actuation, get_actuation_config(device, uart_port)}
      "DsmRxFrskyServo" -> {ActuationCommand, get_actuation_command_config(device, uart_port)}
      "FrskyRxFrskyServo" -> {ActuationCommand, get_actuation_command_config(device, uart_port)}
      "TerarangerEvo" -> {Estimation.TerarangerEvo, get_teraranger_evo_config(uart_port)}
      "VnIns" -> {Estimation.VnIns, get_vn_ins_config(uart_port)}
      "VnImu" -> {Estimation.VnIns, get_vn_imu_config(uart_port)}
      "Xbee" -> {Telemetry, get_telemetry_config(uart_port)}
      "Sik" -> {Telemetry, get_telemetry_config(uart_port)}
      "PwmReader" -> {PwmReader, get_pwm_reader_config(uart_port)}
      "Generic" -> {Generic, get_generic_config(uart_port, metadata)}
    end
  end

  @spec get_dsm_rx_config(atom()) :: list()
  def get_dsm_rx_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "CP2104"),
      rx_module: :Dsm,
      port_options: [
        speed: 115_200,
      ]
    ]
  end

  @spec get_frsky_rx_config(binary()) :: list()
  def get_frsky_rx_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "CP2104"),
      rx_module: :Frsky,
      port_options: [
        speed: 100000,
        stop_bits: 2,
        parity: :even,
      ]
    ]
  end

  @spec get_actuation_config(binary(), binary()) :: list()
  def get_actuation_config(device, uart_port) do
    {interface_module, sim_port} =
      case device do
        "FrskyServo" -> {Peripherals.Uart.Actuation.Frsky.Device, "Feather M0"}
        "PololuServo" -> {Peripherals.Uart.Actuation.Pololu.Device, "Pololu"}
      end
    [
      interface_module: interface_module,
      uart_port: uart_port_real_or_sim(uart_port, sim_port),
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_actuation_command_config(binary(), binary()) :: list()
  def get_actuation_command_config(device, uart_port) do
    {interface_module, rx_module} =
      case device do
        "DsmRxFrskyServo" -> {Peripherals.Uart.Actuation.Frsky.Device, :Dsm}
        "FrskyRxFrskyServo" -> {Peripherals.Uart.Actuation.Frsky.Device, :Frsky}
      end
    [
      interface_module: interface_module,
      uart_port: uart_port_real_or_sim(uart_port, "CP2104"),
      port_options: [
        speed: 115_200,
	      # rx_framing_timeout: 7
      ],
      rx_module: rx_module
    ]
  end


  @spec get_teraranger_evo_config(binary()) :: list()
  def get_teraranger_evo_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "FT232R"),
      port_options: [
        speed: 115_200
      ]
    ]
  end

  @spec get_vn_ins_config(binary()) :: list()
  def get_vn_ins_config(uart_port) do
    [
      # uart_port: uart_port_real_or_sim(uart_port, "USB Serial"),
      uart_port: uart_port_real_or_sim(uart_port, "QT Py"),
      port_options: [speed: 115_200],
      expecting_pos_vel: true
    ]
  end

  @spec get_vn_imu_config(binary()) :: list()
  def get_vn_imu_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "USB Serial"),
      port_options: [speed: 115_200],
      expecting_pos_vel: false
    ]
  end

  @spec get_cp_ins_config(binary()) :: list()
  def get_cp_ins_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "USB Serial"),
      antenna_offset: Common.Constants.pi_2,
      imu_loop_interval_ms: 20,
      ins_loop_interval_ms: 200,
      heading_loop_interval_ms: 200
    ]
  end

  @spec get_telemetry_config(binary()) :: list()
  def get_telemetry_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "FT231X"),
      port_options: [speed: 57_600],
      fast_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
      medium_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:medium),
      slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
    ]
  end

  @spec get_pwm_reader_config(binary()) :: list()
  def get_pwm_reader_config(uart_port) do
    [
      uart_port: uart_port_real_or_sim(uart_port, "Feather M0"),
      port_options: [speed: 115_200],
    ]
  end

  @spec get_generic_config(binary(), binary()) :: list()
  def get_generic_config(uart_port, device_capability) do
    sorter_classification = Configuration.Generic.generic_peripheral_classification(device_capability)
    [
      uart_port: uart_port_real_or_sim(uart_port, "USB Serial"),
      port_options: [speed: 115_200],
      sorter_classification: sorter_classification
    ]
  end

  @spec uart_port_real_or_sim(binary(), binary()) :: binary()
  def uart_port_real_or_sim(real_port, sim_port) do
    if real_port == "usb", do: sim_port, else: real_port
  end

end
