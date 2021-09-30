defmodule Network.Utils do
  require Logger
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
