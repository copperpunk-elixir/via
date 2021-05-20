defmodule Ubx.Utils do
  require Logger

  @spec dispatch_message(integer(), integer(), list(), atom(), list()) :: atom()
  def dispatch_message(msg_class, msg_id, payload, _module, _sorter_classification) do
    Logger.debug("Rx'd msg: #{msg_class}/#{msg_id}")
    Logger.debug("payload: #{inspect(payload)}")
    case msg_class do
      0x10 ->
        case msg_id do
          _other -> Logger.warn("Bad message id: #{msg_id}")
        end
      _other -> Logger.warn("Bad message class: #{msg_class}")
    end
  end

  @spec send_global_with_group(any(), binary(), any()) :: atom()
  def send_global_with_group(group, message, module) do
    Comms.Operator.send_global_msg_to_group(module, message, group, self())
  end

  @spec send_global(tuple(), atom()) :: atom()
  def send_global(message, module) do
    # Logger.debug("send global from #{module} to #{inspect(elem(message,0))}")
    Comms.Operator.send_global_msg_to_group(module, message, elem(message,0), self())
  end

  @spec construct_and_send_message_with_ref(any(), list(), any()) :: atom()
  def construct_and_send_message_with_ref(msg_type, values, uart_ref) do
    # Logger.debug("#{inspect(msg_type)}: #{inspect(values)}")
    values = Common.Utils.assert_list(values)
    msg = Ubx.Interpreter.construct_message(msg_type, values)
    Circuits.UART.write(uart_ref, msg)
#    Circuits.UART.drain(uart_ref)
  end

  @spec construct_and_send_message(any(), list(), atom()) :: atom()
  def construct_and_send_message(msg_type, values, module) do
    Logger.debug("#{inspect(msg_type)}: #{inspect(values)}")
    values = Common.Utils.assert_list(values)
    msg = Ubx.Interpreter.construct_message(msg_type, values)
    send_message(msg, module)
  end

  @spec construct_and_send_proto_message(any(), binary(), atom()) :: atom()
  def construct_and_send_proto_message(msg_type, encoded_payload, module) do
    msg = Ubx.Interpreter.construct_proto_message(msg_type, encoded_payload)
    send_message(msg, module)
  end

  @spec send_message(binary(), atom()) :: atom()
  def send_message(message, module) do
    Logger.debug("module: #{inspect(module)}")
    GenServer.cast(module, {:send_message, message})
  end

  @spec send_message_now(any(), binary()) :: atom()
  def send_message_now(uart_ref, message) do
    Circuits.UART.write(uart_ref, message)
  end

end
