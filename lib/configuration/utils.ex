defmodule Configuration.Utils do
  require Logger

  @spec full_config(binary(), binary(), binary()) :: keyword()
  def full_config(vehicle_type, model_type, node_type) do
    config_module = Module.concat([Configuration, vehicle_type, model_type, node_type, Config])
    Logger.debug("config mod: #{config_module}")
    apply(config_module, :config, [])
  end

  @spec full_config_sim() :: keyword()
  def full_config_sim() do
    full_config("FixedWing", "Cessna", "Sim")
  end

  @spec single_config(atom(), binary(), binary(), binary()) :: keyword()
  def single_config(module, vehicle_type, model_type, node_type) do
    config_module = Module.concat([Configuration, vehicle_type, model_type, node_type, module])
    apply(config_module, :config, [])
  end

  @spec get_vehicle_type() :: binary()
  def get_vehicle_type() do
    get_filename_for_extension!(".vehicle")
  end

  @spec get_node_type() :: binary()
  def get_node_type() do
    get_filename_for_extension!(".node")
  end

  @spec get_model_type() :: binary()
  def get_model_type() do
    get_filename_for_extension!(".model")
  end

  @spec get_filename_for_extension!(binary()) :: binary()
  def get_filename_for_extension!(file_extension) do
    filename = ViaUtils.File.get_filenames_with_extension(file_extension) |> Enum.at(0)

    if is_nil(filename) do
      raise "#{file_extension} does not exist"
    else
      filename
    end
  end

  @spec get_file_safely(binary(), integer(), integer()) :: atom()
  def get_file_safely(file_extension, count, count_max) do
    filename = ViaUtils.File.get_filenames_with_extension(file_extension) |> Enum.at(0)

    if is_nil(filename) and count < count_max do
      Logger.error("#{file_extension} file unavailable. Retry #{count + 1}/#{count_max}")
      Process.sleep(1000)
      get_file_safely(file_extension, count + 1, count_max)
    else
      filename
    end
  end

  @spec get_files_safely(binary(), integer(), integer()) :: list()
  def get_files_safely(file_extension, count, count_max) do
    filenames = ViaUtils.File.get_filenames_with_extension(file_extension)

    if Enum.empty?(filenames) and count < count_max do
      Logger.error("#{file_extension} files unavailable. Retry #{count + 1}/#{count_max}")
      Process.sleep(1000)
      get_files_safely(file_extension, count + 1, count_max)
    else
      filenames
    end
  end

  @spec get_uart_peripherals(binary()) :: list()
  def get_uart_peripherals(subdirectory \\ "") do
    get_peripherals(".uart", subdirectory)
  end

  @spec get_gpio_peripherals(binary()) :: list()
  def get_gpio_peripherals(subdirectory \\ "") do
    get_peripherals(".gpio", subdirectory)
  end

  @spec get_i2c_peripherals(binary()) :: list()
  def get_i2c_peripherals(subdirectory \\ "") do
    get_peripherals(".i2c", subdirectory)
  end

  @spec get_peripherals(binary(), binary()) :: list()
  def get_peripherals(extension, subdirectory) do
    directory = "peripherals/" <> subdirectory
    ViaUtils.File.get_filenames_with_extension(extension, directory)
  end

  @spec split_safely(binary(), binary()) :: list()
  def split_safely(value, delimitter) do
    # Logger.warn("split: #{value} with #{delimitter}")
    case String.split(value, delimitter) do
      [node_type, meta] -> [node_type, meta]
      [node_type] -> [node_type, nil]
    end
  end
end
