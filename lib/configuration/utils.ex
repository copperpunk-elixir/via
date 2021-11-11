defmodule Configuration.Utils do
  require Logger

  @spec config(binary(), binary(), binary(), list()) :: keyword()
  def config(vehicle_type, model_type, node_type, modules \\ []) do
    config_module = Module.concat([Configuration, vehicle_type, model_type, node_type, Config])
    Logger.debug("config mod: #{config_module}")
    Logger.debug("modules (if override): #{inspect(modules)}")
    config(config_module, modules)
  end

  @spec config(module(), list()) :: list()
  def config(config_module, modules \\ []) do
    modules = if Enum.empty?(modules), do: apply(config_module, :modules, []), else: modules
    Logger.debug("modules: #{inspect(modules)}")

    root_module_name =
      Module.split(config_module)
      |> Enum.drop(-1)
      |> Module.concat()

    Enum.reduce(modules, [], fn module, acc ->
      full_module_name = Module.concat(root_module_name, module)
      single_config = apply(full_module_name, :config, [])
      # IO.puts("config for module #{inspect(module)}: #{inspect(single_config)}")
      # IO.puts("full config so far: #{inspect(acc)}")
      Keyword.put(acc, module, single_config)
    end)
  end

  @spec config_sim() :: keyword()
  def config_sim() do
    config("FixedWing", "Cessna", "Sim")
  end

  @spec config_hil() :: keyword()
  def config_hil() do
    config("FixedWing", "Cessna", "Hil")
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

  @spec get_message_sorter_module(module()) :: module()
  def get_message_sorter_module(current_module) do
    Module.split(current_module)
    |> Enum.drop(-1)
    |> Module.concat()
    |> Module.concat(MessageSorter)
  end

  @spec get_vehicle_id(module()) :: integer()
  def get_vehicle_id(node_module) do
    vehicle_module =
      Module.split(node_module)
      |> Enum.take(4)
      |> Kernel.++(["Vehicle"])
      |> Module.concat()

    apply(vehicle_module, :vehicle_id, [])
  end
end
