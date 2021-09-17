defmodule Network.Utils do
  require Logger
  @spec get_ip_address_eth0() :: any()
  def get_ip_address_eth0() do
    module = if Via.Application.target?(), do: Target, else: Host
    apply(Module.concat(Network.Utils, module), :get_ip_address, ["eth0"])
  end

  @spec get_ip_address_wlan0() :: any()
  def get_ip_address_wlan0 do
    module = if Via.Application.target?(), do: Target, else: Host
    apply(Module.concat(Network.Utils, module), :get_ip_address, ["wlan0"])
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

  def add_to_ip_address_last_byte(ip_address, value_to_add) do
    ip_list = String.split(ip_address, ".")
    last_byte = ip_list |> Enum.at(3) |> String.to_integer() |> Kernel.+(value_to_add)

    last_byte =
      cond do
        last_byte > 255 -> 255
        last_byte < 100 -> 100
        true -> last_byte
      end

    List.replace_at(ip_list, 3, Integer.to_string(last_byte)) |> Enum.join(".")
  end
end
