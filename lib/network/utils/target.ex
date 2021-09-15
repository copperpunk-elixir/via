defmodule Network.Utils.Target do
  @spec get_ip_address() :: any()
  def get_ip_address() do
    get_ip_address_for_interfaces(VintageNet.all_interfaces())
  end

  @spec get_ip_address_for_interfaces(list()) :: any()
  def get_ip_address_for_interfaces(interfaces) do
    {[interface], remaining} = Enum.split(interfaces, 1)
    all_ip_configs = VintageNet.get(["interface", interface, "addresses"], [])
    # Logger.debug("all ip configs: #{inspect(all_ip_configs)}")
    address = Enum.find(all_ip_configs, fn ip_config -> ip_config.family == :inet end)

    cond do
      !is_nil(address) -> address
      Enum.empty?(remaining) -> nil
      true -> get_ip_address_for_interfaces(remaining)
    end
  end
end
