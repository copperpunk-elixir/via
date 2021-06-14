defmodule Common.Utils.Configuration do
  require Logger

  @file_lookup_count_max 10

  @spec full_config(binary(), binary(), binary()) :: keyword()
  def full_config(vehicle_type, model_type, node_type) do
    config_module = Module.concat([Configuration, vehicle_type, model_type, node_type, Config])
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
    get_file_safely(".vehicle", 1, @file_lookup_count_max)
  end

  @spec get_node_type() :: binary()
  def get_node_type() do
    get_file_safely(".node", 1, @file_lookup_count_max)
  end

  @spec get_model_type() :: binary()
  def get_model_type() do
    get_file_safely(".model", 1, @file_lookup_count_max)
  end

  @spec root_module(binary(), binary(), binary()) :: atom()
  def root_module(vehicle_type, model_type, node_type) do
    Module.concat(vehicle_type, model_type)
    |> Module.concat(node_type)
  end

  @spec get_modules() :: list()
  def get_modules() do
    Common.Utils.File.get_filenames_with_extension(".module")
  end

  @spec get_file_safely(binary(), integer(), integer()) :: atom()
  def get_file_safely(file_extension, count, count_max) do
    filename = Common.Utils.File.get_filenames_with_extension(file_extension) |> Enum.at(0)

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
    filenames = Common.Utils.File.get_filenames_with_extension(file_extension)

    if Enum.empty?(filenames) and count < count_max do
      Logger.error("#{file_extension} files unavailable. Retry #{count + 1}/#{count_max}")
      Process.sleep(1000)
      get_files_safely(file_extension, count + 1, count_max)
    else
      filenames
    end
  end

  @spec is_hil?() :: boolean()
  def is_hil?() do
    hil = Common.Utils.File.get_filenames_with_extension(".hil")
    !Enum.empty?(hil)
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
    Common.Utils.File.get_filenames_with_extension(extension, directory)
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
