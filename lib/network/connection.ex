defmodule Network.Connection do
  require Logger

  @spec get_ip_address_eth0() :: any()
  def get_ip_address_eth0 do
    get_ip_address("eth0")
  end

  @spec get_ip_address_wlan0() :: any()
  def get_ip_address_wlan0 do
    get_ip_address("wlan0")
  end

  @spec get_ip_address(binary()) :: tuple()
  def get_ip_address(interface) do
    all_ip_configs = VintageNet.get(["interface", interface, "addresses"], [])
    # Logger.debug("all ip configs: #{inspect(all_ip_configs)}")
    get_inet_ip_address(all_ip_configs)
  end

  @spec get_ip_address_for_interfaces(list()) :: tuple()
  def get_ip_address_for_interfaces(interfaces) do
    {[interface], remaining} = Enum.split(interfaces, 1)
    all_ip_configs = VintageNet.get(["interface", interface, "addresses"], [])
    # Logger.debug("all ip configs: #{inspect(all_ip_configs)}")
    address = get_inet_ip_address(all_ip_configs)

    cond do
      !is_nil(address) -> address
      Enum.empty?(remaining) -> ""
      true -> get_ip_address_for_interfaces(remaining)
    end
  end

  @spec get_inet_ip_address(list()) :: tuple()
  def get_inet_ip_address(all_ip_configs) when length(all_ip_configs) == 0 do
    nil
  end

  @spec get_inet_ip_address(list()) :: tuple()
  def get_inet_ip_address(all_ip_configs) do
    {[config], remaining} = Enum.split(all_ip_configs, 1)

    if config.family == :inet do
      Logger.debug("Found #{inspect(config.address)} for family: #{config.family}")
      config.address
    else
      get_inet_ip_address(remaining)
    end
  end

  @spec open_socket(integer(), integer()) :: {any(), integer()}
  def open_socket(src_port, attempts) do
    Logger.debug("open socket on port #{src_port}")

    if attempts > 10 do
      raise "Could not open socket after 10 attempts"
    end

    case :gen_udp.open(src_port, broadcast: true, active: true) do
      {:ok, socket} -> {socket, src_port}
      {:error, :eaddrinuse} -> open_socket(src_port + 1, attempts + 1)
      other -> raise "Unknown error: #{inspect(other)}"
    end
  end
end
