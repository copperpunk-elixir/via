defmodule Peripherals.Uart.Utils do
  require Logger
  @spec open_interface_connection(atom(), any(), integer(), integer()) :: any()
  def open_interface_connection(interface_module, interface, connection_count, connection_count_max) do
    case apply(interface_module, :open_port, [interface]) do
      nil ->
        if (connection_count < connection_count_max) do
          Logger.debug("#{interface_module} is unavailable. Retrying in 1 second.")
          Process.sleep(1000)
          open_interface_connection(interface_module, interface, connection_count+1, connection_count_max)
        else
          raise "#{interface_module} is unavailable"
        end
      interface -> interface
    end
  end

  @spec open_interface_connection_infinite(any(), binary(), list(), integer) :: atom()
  def open_interface_connection_infinite(interface_ref, device_description, options, num_tries \\ 1) do
    port = Peripherals.Uart.Utils.get_uart_devices_containing_string(device_description)
    Logger.debug("Opening #{device_description}. Attempt #{num_tries}")
    case Circuits.UART.open(interface_ref,port, options) do
      {:error, error} ->
        Logger.error("Error opening UART #{device_description}: #{inspect(error)}. Retrying in 1s")
        Process.sleep(1000)
        open_interface_connection_infinite(interface_ref, device_description, options, num_tries + 1)
      _success ->
        Logger.debug("#{device_description} opened UART")
    end
  end

  @spec get_uart_devices_containing_string(binary()) :: list()
  def get_uart_devices_containing_string(device_string) do
    if String.contains?(device_string, "ttyAMA") or String.contains?(device_string, "ttyS0") do
      # open port directly
      device_string
    else
      device_string = String.downcase(device_string)
      Logger.debug("devicestring: #{device_string}")
      uart_ports = Circuits.UART.enumerate()
      Logger.debug("ports: #{inspect(uart_ports)}")
      matching_ports = Enum.reduce(uart_ports, [], fn ({port_name, port}, acc) ->
        device_description = Map.get(port, :description,"")
        Logger.debug("description: #{String.downcase(device_description)}")
        if String.contains?(String.downcase(device_description), device_string) do
          acc ++ [port_name]
        else
          acc
        end
      end)
      if length(matching_ports) == 0, do: nil, else: Enum.min(matching_ports)
    end
  end
end
