defmodule Common.Utils do
  require Logger
  use Bitwise

  def start_link_redundant(parent_module, module, config, name \\ nil) do
    name =
      case name do
        nil -> module
        atom -> atom
      end
    result =
      case parent_module do
        GenServer -> GenServer.start_link(module, config, name: name)
        Supervisor -> Supervisor.start_link(module, config, name: name)
        DynamicSupervisor -> DynamicSupervisor.start_link(module, config, name: name)
        Registry -> apply(Registry, :start_link, [config])
        Agent -> Agent.start_link(fn -> config end, name: name)
      end
    case result do
      {:ok, pid} ->
        # Logger.debug("#{module}: #{inspect(name)} successfully started")
        wait_for_genserver_start(pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        # Logger.debug("#{module}: #{inspect(name)} already started at #{inspect(pid)}. This is fine.")
        {:ok, pid}
    end
  end

  def start_link_singular(parent_module, module, config, name \\ nil) do
    name =
      case name do
        nil -> module
        atom -> atom
      end
    result =
      case parent_module do
        GenServer -> GenServer.start_link(module, config, name: name)
        Supervisor -> Supervisor.start_link(module, config, name: name)
        DynamicSupervisor -> DynamicSupervisor.start_link(module, config, name: name)
        Registry -> apply(Registry, :start_link, [config])
        Agent -> Agent.start_link(fn -> config end, name: name)
      end
    case result do
      {:ok, pid} ->
        # Logger.debug("#{module}: #{inspect(name)} successfully started")
        wait_for_genserver_start(pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        raise "#{module}: #{inspect(name)} already started at #{inspect(pid)}. This is not okay."
        {:error, pid}
    end
  end

  def wait_for_genserver_start(process_name, current_time \\ 0, timeout \\ 60000) do
    # Logger.debug("Wait for GenServer process: #{inspect(process_name)}")
    if GenServer.whereis(process_name) == nil do
      if current_time < timeout do
        Process.sleep(100)
        wait_for_genserver_start(process_name, current_time + 10, timeout)
      else
        Logger.error("Wait for GenServer Start TIMEOUT. Waited #{timeout/1000}s")
      end
    end
  end

  @spec prepare_test(binary(), binary()) :: atom()
  def prepare_test(model_type, node_type) do
    Common.Application.prepare_environment()
    Boss.System.start_universal_modules(model_type, node_type)
  end

  def assert_list(value_or_list) do
    if is_list(value_or_list) do
      value_or_list
    else
      [value_or_list]
    end
  end

  def list_to_enum(input_list) do
    input_list
    |> Enum.with_index()
    |> Map.new()
  end

  def assert_valid_config(config, config_type) do
    {verify_fn, default_value} =
      case config_type do
        Map -> {:is_map, %{}}
        List -> {:is_list, []}
      end
    if apply(Kernel, verify_fn, [config]) do
      config
    else
      default_value
    end
  end
  # def validate_config_with_default(config,, default_config) do
  # end

  def start_loop(process_id, loop_interval_ms, loop_callback) do
      case :timer.send_interval(loop_interval_ms, process_id, loop_callback) do
        {:ok, timer} ->
          # Logger.debug("#{inspect(loop_callback)} timer started!")
          timer
        {_, reason} ->
          Logger.warn("Could not start #{(loop_callback)} timer: #{inspect(reason)} ")
          nil
      end
  end

  def stop_loop(timer) do
    case :timer.cancel(timer) do
      {:ok, _} ->
        nil
      {_, reason} ->
        Logger.warn("Could not stop #{inspect(timer)} timer: #{inspect(reason)} ")
        timer
    end
  end

  # Erlang float_to_binary shorthand
  @spec eftb(float(), integer()) :: binary()
  def eftb(number, num_decimals) do
    :erlang.float_to_binary(number/1, [decimals: num_decimals])
  end

  @spec eftb_deg(float(), integer()) ::binary()
  def eftb_deg(number, num_decimals) do
    :erlang.float_to_binary(Common.Utils.Math.rad2deg(number), [decimals: num_decimals])
  end

  @spec eftb_deg_sign(float(), integer()) :: binary()
  def eftb_deg_sign(number, num_decimals) do
    str = eftb_deg(number, num_decimals)
    if (number >= 0), do: "+" <> str, else: str
  end

  @spec eftb_rad(float(), integer()) ::binary()
  def eftb_rad(number, num_decimals) do
    :erlang.float_to_binary(Common.Utils.Math.deg2rad(number), [decimals: num_decimals])
  end

  @spec eftb_list(list(), integer(), binary()) :: binary()
  def eftb_list(numbers, num_decimals, separator \\ "/") do
    Enum.reduce(numbers, "", fn (number, acc) ->
      acc <> :erlang.float_to_binary(number/1, [decimals: num_decimals]) <> separator
    end)
  end

  @spec eftb_map(map(), integer(), binary()) ::binary()
  def eftb_map(keys_values, num_decimals, separator \\ ",") do
    Enum.reduce(keys_values, "", fn ({key,value}, acc) ->
      acc <> "#{inspect(key)}: " <> :erlang.float_to_binary(value/1, [decimals: num_decimals]) <> separator
    end)
  end

  @spec eftb_map_deg(map(), integer(), binary()) ::binary()
  def eftb_map_deg(keys_values, num_decimals, separator \\ ",") do
    Enum.reduce(keys_values, "", fn ({key,value}, acc) ->
      acc <> "#{inspect(key)}: " <> :erlang.float_to_binary(Common.Utils.Math.rad2deg(value), [decimals: num_decimals]) <> separator
    end)
  end

  @spec map_rad2deg(map()) :: map()
  def map_rad2deg(values) do
    Enum.reduce(values, %{}, fn ({key, value}, acc) ->
    Map.put(acc, key, Common.Utils.Math.rad2deg(value))
    end)
  end

  @spec map_deg2rad(map()) :: map()
  def map_deg2rad(values) do
    Enum.reduce(values, %{}, fn ({key, value}, acc) ->
    Map.put(acc, key, Common.Utils.Math.deg2rad(value))
    end)
  end

  def list_to_int(x_list, bytes) do
    Enum.reduce(0..bytes-1, 0, fn(index,acc) ->
      acc + (Enum.at(x_list,index)<<<(8*index))
    end)
  end

  @spec get_key_or_value(any(), any()) :: any()
  def get_key_or_value(keys_values, id) do
    Enum.reduce(keys_values, nil, fn ({key, value}, acc) ->
      cond do
        (key == id) -> value
        (value == id) -> key
        true -> acc
      end
    end)
  end

  @spec default_to(any(), any()) :: any()
  def default_to(input, default_value) do
    if is_nil(input), do: default_value, else: input
  end

  @spec power_off() ::tuple()
  def power_off() do
    # System.cmd("poweroff", ["now"])
    Nerves.Runtime.poweroff()
  end

  @spec index_for_embedded_value(list(), any(), any(), integer()) :: integer()
  def index_for_embedded_value(container, key, value, index \\ 0) do
    {[item], remaining} = Enum.split(container, 1)
    if Map.get(item, key,:undefined) == value do
      index
    else
      if Enum.empty?(remaining) do
        nil
      else
        index_for_embedded_value(remaining, key, value, index+1)
      end
    end
  end

  @spec mod_bin_mod_concat(atom(), binary(), atom()) :: atom()
  def mod_bin_mod_concat(module1, binary2, module3) do
      Module.concat(module1, String.to_existing_atom(binary2))
      |> Module.concat(module3)
  end

  @spec is_target?() :: boolean()
  def is_target? do
    String.contains?(File.cwd!(), "/srv/erlang")
  end
end
