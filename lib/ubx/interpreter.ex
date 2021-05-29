defmodule Ubx.Interpreter do
  require Logger
  use Bitwise

  @max_payload_length 1000

  @start_byte_1 0xB5
  @start_byte_2 0x62

  @got_none 0
  @got_start_byte1 1
  @got_start_byte2 2
  @got_class 3
  @got_id 4
  @got_length1 5
  @got_length2 6
  @got_payload 7
  @got_chka 8

  defstruct state: @got_none,
            msg_class: -1,
            msg_id: -1,
            msg_len: -1,
            chka: 0,
            chkb: 0,
            count: 0,
            payload_rev: [],
            payload_ready: false

  @spec new() :: struct()
  def new() do
    %Ubx.Interpreter{}
  end

  @spec parse_data(struct(), list()) :: {struct(), list()}
  def parse_data(ubx, data) do
    unless Enum.empty?(data) do
      {[byte], remaining_data} = Enum.split(data, 1)
      ubx = parse_byte(ubx, byte)

      cond do
        ubx.payload_ready -> {ubx, remaining_data}
        Enum.empty?(remaining_data) -> {ubx, []}
        true -> parse_data(ubx, remaining_data)
      end
    else
      {ubx, []}
    end
  end

  @spec parse_byte(struct(), integer()) :: struct()
  def parse_byte(ubx, byte) do
    state = ubx.state
    # Logger.debug("state/byte/count: #{state}/#{byte}/#{ubx.count}")

    cond do
      state == @got_none and byte == @start_byte_1 ->
        %{ubx | state: @got_start_byte1}

      state == @got_start_byte1 ->
        if byte == @start_byte_2 do
          %{ubx | state: @got_start_byte2, chka: 0, chkb: 0, payload_rev: []}
        else
          %{ubx | state: @got_none}
        end

      state == @got_start_byte2 ->
        msgclass = byte
        {chka, chkb} = add_to_checksum(ubx, byte)
        %{ubx | state: @got_class, msg_class: msgclass, chka: chka, chkb: chkb}

      state == @got_class ->
        msgid = byte
        {chka, chkb} = add_to_checksum(ubx, byte)
        %{ubx | state: @got_id, msg_id: msgid, chka: chka, chkb: chkb}

      state == @got_id ->
        msglen = byte
        {chka, chkb} = add_to_checksum(ubx, byte)
        %{ubx | state: @got_length1, msg_len: msglen, chka: chka, chkb: chkb}

      state == @got_length1 ->
        msglen = ubx.msg_len + Bitwise.<<<(byte, 8)
        # Logger.debug("msglen: #{msglen}")
        if msglen <= @max_payload_length do
          {chka, chkb} = add_to_checksum(ubx, byte)
          %{ubx | state: @got_length2, msg_len: msglen, count: 0, chka: chka, chkb: chkb}
        else
          Logger.error("payload overload")
          %{ubx | state: @got_none}
        end

      state == @got_length2 ->
        {chka, chkb} = add_to_checksum(ubx, byte)
        payload_rev = [byte] ++ ubx.payload_rev
        count = ubx.count + 1
        state = if count == ubx.msg_len, do: @got_payload, else: ubx.state
        %{ubx | state: state, chka: chka, chkb: chkb, count: count, payload_rev: payload_rev}

      state == @got_payload ->
        state = if byte == ubx.chka, do: @got_chka, else: @got_none
        # if (state == @got_none), do: Logger.warn("bad a")
        %{ubx | state: state}

      state == @got_chka ->
        state = @got_none
        payload_ready = if byte == ubx.chkb, do: true, else: false
        # if (!payload_ready), do: Logger.warn("bad b")
        %{ubx | state: state, payload_ready: payload_ready}

      true ->
        # Garbage byte
        # Logger.warn("parse unexpected condition")
        %{ubx | state: @got_none}
    end
  end

  @spec add_to_checksum(struct(), integer()) :: tuple()
  def add_to_checksum(ubx, byte) do
    chka = Bitwise.&&&(ubx.chka + byte, 0xFF)
    chkb = Bitwise.&&&(ubx.chkb + chka, 0xFF)
    {chka, chkb}
  end

  @spec payload(struct()) :: list()
  def payload(ubx) do
    Enum.reverse(ubx.payload_rev)
  end

  @spec clear(struct()) :: struct()
  def clear(ubx) do
    %{ubx | payload_ready: false}
  end

  @spec msg_class_and_id(struct()) :: tuple()
  def msg_class_and_id(ubx) do
    {ubx.msg_class, ubx.msg_id}
  end

  # @spec get_itow() :: integer()
  # def get_itow() do
  #   get_itow(DateTime.utc_now)
  # end

  @spec get_itow(struct(), struct()) :: integer()
  def get_itow(now, today) do
    first_day_str =
      Date.add(today, -Date.day_of_week(today) + 1)
      |> Date.to_iso8601()
      |> Kernel.<>("T00:00:00Z")

    {:ok, first_day, 0} = DateTime.from_iso8601(first_day_str)

    DateTime.diff(now, first_day, :millisecond)
  end

  @spec process_data(struct(), list(), fun(), list()) :: struct()
  def process_data(ubx, data, process_fn, additional_fn_args) do
    {ubx, remaining_data} = parse_data(ubx, data)

    if ubx.payload_ready do
      msg_class = ubx.msg_class
      msg_id = ubx.msg_id
      payload = payload(ubx)
      # Logger.debug("Rx'd msg: #{msg_class}/#{msg_id}")
      # Logger.debug("payload: #{inspect(Ubx.Interpreter.payload(ubx))}")
      apply(process_fn, [msg_class, msg_id, payload] ++ additional_fn_args)

      clear(ubx)
      |> process_data(remaining_data, process_fn, additional_fn_args)
    else
      ubx
    end
  end
end
