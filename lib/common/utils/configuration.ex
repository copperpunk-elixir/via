defmodule Common.Utils.Configuration do
  require Logger

  @file_lookup_count_max 10

  @spec get_vehicle_type(atom()) :: binary()
  def get_vehicle_type(model_type) do
    case model_type do
      "Cessna" -> "Plane"
      "CessnaZ2m" -> "Plane"
      "T28" -> "Plane"
      "T28Z2m" -> "Plane"
      "QuadX" -> "Multirotor"
      "FerrariF1" -> "Car"
      _other -> raise "Unknown model"
    end
  end

  @spec get_node_type() :: binary()
  def get_node_type() do
    get_file_safely(".node", 1, @file_lookup_count_max)
  end

  @spec get_model_type() :: binary()
  def get_model_type() do
    get_file_safely(".model", 1, @file_lookup_count_max)
  end

  @spec get_modules() :: list()
  def get_modules() do
    Common.Utils.File.get_filenames_with_extension(".module")
  end

  @spec get_file_safely(binary(), integer(), integer()) :: atom()
  def get_file_safely(file_extension, count, count_max) do
    filename = Common.Utils.File.get_filenames_with_extension(file_extension) |> Enum.at(0)
    if is_nil(filename) and (count < count_max) do
      Logger.error("#{file_extension} file unavailable. Retry #{count+1}/#{count_max}")
      Process.sleep(1000)
      get_file_safely(file_extension, count+1, count_max)
    else
      filename
    end
  end

  @spec get_files_safely(binary(), integer(), integer()) :: list()
  def get_files_safely(file_extension, count, count_max) do
    filenames = Common.Utils.File.get_filenames_with_extension(file_extension)
    if Enum.empty?(filenames) and (count < count_max) do
      Logger.error("#{file_extension} files unavailable. Retry #{count+1}/#{count_max}")
      Process.sleep(1000)
      get_files_safely(file_extension, count+1, count_max)
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
  def split_safely(value, delimitter)do
    # Logger.warn("split: #{value} with #{delimitter}")
    case String.split(value, delimitter) do
      [node_type, meta] -> [node_type, meta]
      [node_type] -> [node_type, nil]
    end
  end
end
