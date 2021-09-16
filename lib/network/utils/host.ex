defmodule Network.Utils.Host do
  @spec get_ip_address() :: any()
  def get_ip_address() do
    {:ok, interfaces} = :inet.getifaddrs()

    with(
      {_interface, config} <-
        Enum.find(interfaces, fn {_interface, config} ->
          Enum.member?(config[:flags], :up) and !Enum.member?(config[:flags], :loopback) and
            List.keymember?(config, :addr, 0)
        end),
      {:addr, ip_address} <-
        Enum.find(config, fn {key, value} ->
          key == :addr and tuple_size(value) == 4
        end)
    ) do
      ip_address
    else
      _other -> nil
    end
  end
end
