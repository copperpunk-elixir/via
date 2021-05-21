defmodule Ubx.Utils do
  require Logger

  @spec deconstruct_message(list(), list()) :: list()
  def deconstruct_message(byte_types, payload) do
    # byte_types = get_bytes_for_msg(msg_type)
    {_payload_rem, values} =
      Enum.reduce(byte_types, {payload, []}, fn bytes, {remaining_buffer, values} ->
        bytes_abs = abs(bytes) |> round()
        {buffer, remaining_buffer} = Enum.split(remaining_buffer, bytes_abs)

        value = Common.Utils.list_to_int(buffer, bytes_abs)

        value =
          if is_float(bytes) do
            Common.Utils.Math.fp_from_uint(value, bytes_abs * 8)
          else
            if bytes > 0 do
              value
            else
              Common.Utils.Math.twos_comp(value, bytes_abs * 8)
            end
          end

        {remaining_buffer, values ++ [value]}
      end)
    values
  end

  @spec construct_message(integer(), integer(), list(), list()) :: binary()
  def construct_message(msg_class, msg_id, byte_types, values) do
    {payload, payload_length} =
      Enum.reduce(Enum.zip(values, byte_types), {<<>>, 0}, fn {value, bytes},
                                                              {payload, payload_length} ->
        bytes_abs = abs(bytes) |> round()

        value_bin =
          if is_float(bytes) do
            Common.Utils.Math.uint_from_fp(value, round(bytes_abs * 8))
          else
            Common.Utils.Math.int_little_bin(value, bytes_abs * 8)
          end

        {payload <> value_bin, payload_length + bytes_abs}
      end)

    payload_len_msb = Bitwise.>>>(payload_length, 8) |> Bitwise.&&&(0xFF)
    payload_len_lsb = Bitwise.&&&(payload_length, 0xFF)
    checksum_buffer = <<msg_class, msg_id, payload_len_lsb, payload_len_msb>> <> payload
    checksum = calculate_ubx_checksum(:binary.bin_to_list(checksum_buffer))
    <<0xB5, 0x62>> <> checksum_buffer <> checksum
  end

  @spec construct_proto_message(integer(), integer(), binary()) :: binary()
  def construct_proto_message(msg_class, msg_id, payload) do
    payload_list = :binary.bin_to_list(payload)
    payload_length = length(payload_list)
    # Logger.debug("payload len: #{payload_length}")
    payload_len_msb = Bitwise.>>>(payload_length, 8) |> Bitwise.&&&(0xFF)
    payload_len_lsb = Bitwise.&&&(payload_length, 0xFF)
    # Logger.debug("msb/lsb: #{payload_len_msb}/#{payload_len_lsb}")
    checksum_buffer = [msg_class, msg_id, payload_len_lsb, payload_len_msb] ++ payload_list
    checksum = calculate_ubx_checksum(checksum_buffer)
    <<0xB5, 0x62>> <> :binary.list_to_bin(checksum_buffer) <> checksum
  end

  @spec send_global_with_group(any(), binary(), any()) :: atom()
  def send_global_with_group(group, message, module) do
    Comms.Operator.send_global_msg_to_group(module, message, group, self())
  end

  @spec send_global(tuple(), atom()) :: atom()
  def send_global(message, module) do
    # Logger.debug("send global from #{module} to #{inspect(elem(message,0))}")
    Comms.Operator.send_global_msg_to_group(module, message, elem(message, 0), self())
  end

  @spec construct_and_send_message_with_ref(integer(), integer(), list(), list(), any()) :: atom()
  def construct_and_send_message_with_ref(msg_class, msg_id, byte_types, values, uart_ref) do
    # Logger.debug("#{inspect(msg_type)}: #{inspect(values)}")
    values = Common.Utils.assert_list(values)
    msg = construct_message(msg_class, msg_id, byte_types, values)
    Circuits.UART.write(uart_ref, msg)
    #    Circuits.UART.drain(uart_ref)
  end

  @spec construct_and_send_message(integer(), integer(), list(), list(), atom()) :: atom()
  def construct_and_send_message(msg_class, msg_id, byte_types, values, module) do
    Logger.debug("(#{msg_class},#{msg_id}): #{inspect(values)}")
    values = Common.Utils.assert_list(values)
    msg = construct_message(msg_class, msg_id, byte_types, values)
    send_message(msg, module)
  end

  @spec construct_and_send_proto_message(integer(), integer(), binary(), atom()) :: atom()
  def construct_and_send_proto_message(msg_class, msg_id, encoded_payload, module) do
    msg = construct_proto_message(msg_class, msg_id, encoded_payload)
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

  @spec calculate_ubx_checksum(list()) :: binary()
  def calculate_ubx_checksum(buffer) do
    {ck_a, ck_b} =
      Enum.reduce(buffer, {0, 0}, fn x, {ck_a, ck_b} ->
        ck_a = ck_a + x
        ck_b = ck_b + ck_a
        {Bitwise.&&&(ck_a, 0xFF), Bitwise.&&&(ck_b, 0xFF)}
      end)
    <<ck_a, ck_b>>
  end
end
