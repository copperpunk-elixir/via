defmodule Ubx.Interpreter do
  require Logger
  use Bitwise

  @max_payload_length 1000

  @got_none 0
	@got_sync1 1
	@got_sync2 2
	@got_class 3
	@got_id 4
	@got_length1 5
	@got_length2 6
	@got_payload 7
	@got_chka 8

  defstruct [state: @got_none, msg_class: -1, msg_id: -1, msg_len: -1, chka: 0, chkb: 0, count: 0, payload_rev: [], payload_ready: false]

  @spec new() :: struct()
  def new() do
    %Ubx.Interpreter{}
  end

  @spec parse(struct(), list(), atom(), list()) :: struct()
  def parse(ubx, buffer, module, sorter_classification \\ nil) do
    {[byte], buffer} = Enum.split(buffer,1)
    ubx = parse(ubx, byte)
    ubx =
    if ubx.payload_ready == true do
      # Logger.debug("ready")
      {msg_class, msg_id} = msg_class_and_id(ubx)
      Ubx.Utils.dispatch_message(msg_class, msg_id, payload(ubx), module, sorter_classification)
      clear(ubx)
    else
      ubx
    end
    if (Enum.empty?(buffer)) do
      ubx
    else
      parse(ubx, buffer, module, sorter_classification)
    end
  end

  @spec parse(struct(), integer()) :: struct()
  def parse(ubx, byte) do
    state = ubx.state
    # Logger.debug("state/byte/count: #{state}/#{byte}/#{ubx.count}")
    cond do
      state == @got_none and byte == 0xB5 -> %{ubx | state: @got_sync1}
      state == @got_sync1 ->
        if (byte == 0x62) do
          %{ubx | state: @got_sync2, chka: 0, chkb: 0, payload_rev: []}
        else
          %{ubx | state: @got_none}
        end
      state == @got_sync2 ->
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
        msglen = ubx.msg_len + Bitwise.<<<(byte,8)
        # Logger.debug("msglen: #{msglen}")
        if (msglen <= @max_payload_length) do
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
        state = if (count == ubx.msg_len), do: @got_payload, else: ubx.state
        %{ubx | state: state, chka: chka, chkb: chkb, count: count, payload_rev: payload_rev}
      state == @got_payload ->
        state = if (byte == ubx.chka), do: @got_chka, else: @got_none
        # if (state == @got_none), do: Logger.warn("bad a")
        %{ubx | state: state}
      state == @got_chka ->
        state = @got_none
        payload_ready = if (byte == ubx.chkb), do: true, else: false
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

  @spec deconstruct_message(atom(), list()) :: list()
  def deconstruct_message(msg_type, payload) do
    byte_types = get_bytes_for_msg(msg_type)
    {_payload_rem, values} = Enum.reduce(byte_types, {payload, []}, fn (bytes, {remaining_buffer, values}) ->
      bytes_abs = abs(bytes) |> round()
      {buffer, remaining_buffer} = Enum.split(remaining_buffer, bytes_abs)

      value = Common.Utils.list_to_int(buffer, bytes_abs)
      value = if is_float(bytes) do
        Common.Utils.Math.fp_from_uint(value, bytes_abs*8)
      else
        if bytes > 0 do
          value
        else
          Common.Utils.Math.twos_comp(value, bytes_abs*8)
        end
      end
      {remaining_buffer, values ++ [value]}
    end)
    values
  end

  @spec construct_message(any(), list()) :: binary()
  def construct_message(msg_type, values) do
    {msg_class, msg_id} = get_class_and_id_for_msg(msg_type)
    byte_types = get_bytes_for_msg(msg_type)
    {payload, payload_length} = Enum.reduce(Enum.zip(values, byte_types), {<<>>,0}, fn ({value, bytes}, {payload, payload_length}) ->
      bytes_abs = abs(bytes) |> round()
      value_bin = if is_float(bytes) do
        Common.Utils.Math.uint_from_fp(value, round(bytes_abs*8))
      else
        Common.Utils.Math.int_little_bin(value, bytes_abs*8)
      end
      {payload <> value_bin, payload_length + bytes_abs}
    end)

    payload_len_msb = Bitwise.>>>(payload_length,8) |> Bitwise.&&&(0xFF)
    payload_len_lsb = Bitwise.&&&(payload_length, 0xFF)
    checksum_buffer = <<msg_class, msg_id, payload_len_lsb, payload_len_msb>> <> payload
    checksum = calculate_ubx_checksum(:binary.bin_to_list(checksum_buffer))
    <<0xB5, 0x62>> <> checksum_buffer <> checksum
  end

  @spec construct_proto_message(any(), binary()) :: binary()
  def construct_proto_message(msg_type, payload) do
    {msg_class, msg_id} = get_class_and_id_for_msg(msg_type)
    payload_list = :binary.bin_to_list(payload)
    payload_length = length(payload_list)
    # Logger.debug("payload len: #{payload_length}")
    payload_len_msb = Bitwise.>>>(payload_length,8) |> Bitwise.&&&(0xFF)
    payload_len_lsb = Bitwise.&&&(payload_length, 0xFF)
    # Logger.debug("msb/lsb: #{payload_len_msb}/#{payload_len_lsb}")
    checksum_buffer = [msg_class, msg_id, payload_len_lsb, payload_len_msb] ++ payload_list
    checksum = calculate_ubx_checksum(checksum_buffer)
    <<0xB5, 0x62>> <> :binary.list_to_bin(checksum_buffer) <> checksum
  end

  # @spec get_itow() :: integer()
  # def get_itow() do
  #   get_itow(DateTime.utc_now)
  # end

  @spec get_itow(struct(), struct()) :: integer()
  def get_itow(now, today) do
    first_day_str = Date.add(today, - Date.day_of_week(today)+1) |> Date.to_iso8601()
    |> Kernel.<>("T00:00:00Z")
    {:ok, first_day, 0} = DateTime.from_iso8601(first_day_str)

    DateTime.diff(now, first_day, :millisecond)
  end

  @spec calculate_ubx_checksum(list()) :: binary()
  def calculate_ubx_checksum(buffer) do
    {ck_a, ck_b} =
      Enum.reduce(buffer,{0,0}, fn (x,{ck_a, ck_b}) ->
        ck_a = ck_a + x
        ck_b = ck_b + ck_a
        {Bitwise.&&&(ck_a,0xFF), Bitwise.&&&(ck_b,0xFF)}
      end)
    <<ck_a,ck_b>>
  end

  @spec get_bytes_for_msg(atom()) :: list()
  def get_bytes_for_msg(msg_type) do
    case msg_type do
      :ubx_posllh -> [4, -4, -4, -4, -4, 4, 4]
      :accel_gyro -> [4, -4, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0]
      :dtAG -> [2, -2, -2, -2, -2, -2, -2]
      :attitude_thrust -> [-2, -2, 2, 2, -2, -2, 2]
      :bodyrate_thrust -> [-2, -2, -2, 2]
      {:telemetry, :pvat} -> [4, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0]
      {:tx_goals, 1} -> [4, 4.0, 4.0, 4.0, 4.0]
      {:tx_goals, 2} -> [4, 4.0, 4.0, 4.0, 4.0]
      {:tx_goals, 3} -> [4, 4.0, 4.0, 4.0]
      :control_state -> [4, 1]
      :tx_battery -> [4, 4, 4.0, 4.0, 4.0]
      :cluster_status -> [4, 1]
      :set_pid_gain -> [-4,-4,-4,4]
      :request_pid_gain -> [-4, -4, -4]
      # :get_pid_gain -> [-4, -4, -4, 4]
      :change_peripheral_control -> [1]
      :rpc -> [4, 4]
      # :mission -> [-4, -4, -4, -4, -4, -4]
      :clear_mission -> [1]
      :orbit_confirmation -> [4.0, 4.0, 4.0, 4.0]
      :orbit_inline -> [4.0, 1]
      :orbit_centered -> [4.0, 1]
      :orbit_at_location -> [4.0, 4.0, 4.0, 4.0, 1]
      :clear_orbit -> [1]
      :generic_sub -> [1, 4]
      {:pwm_reader, num_chs} -> Enum.reduce(1..num_chs, [], fn (_x,acc) -> acc ++ [2] end)
      _other ->
        Logger.error("Non-existent msg_type")
        []
    end
  end

  @spec get_class_and_id_for_msg(any())::tuple()
  def get_class_and_id_for_msg(msg_type) do
    case msg_type do
      :ubx_posllh -> {0x01, 0x02}
      :accel_gyro -> {0x01, 0x69}
      :dtAG -> {0x11, 0x00}
      :attitude_thrust -> {0x12, 0x00}
      :bodyrate_thrust -> {0x12, 0x01}
      {:telemetry, :pvat} -> {0x45, 0x00}
      {:tx_goals, 1} -> {0x45, 0x11}
      {:tx_goals, 2} -> {0x45, 0x12}
      {:tx_goals, 3} -> {0x45, 0x13}
      :control_state -> {0x45, 0x14}
      :tx_battery -> {0x45, 0x15}
      :cluster_status -> {0x45, 0x16}
      :set_pid_gain -> {0x46, 0x00}
      :request_pid_gain -> {0x46, 0x01}
      # :get_pid_gain -> {0x46, 0x02}
      :change_peripheral_control -> {0x46, 0x03}
      :rpc  -> {0x50, 0x00}
      :mission_proto -> {0x50, 0x01}
      :clear_mission -> {0x50, 0x02}
      :save_log_proto -> {0x50, 0x03}
      :orbit_confirmation -> {0x51, 0x00}
      :orbit_inline -> {0x52, 0x00}
      :orbit_centered -> {0x52, 0x01}
      :orbit_at_location -> {0x52, 0x02}
      :clear_orbit -> {0x52, 0x03}
      :generic_sub -> {0x60, 0x00}
      _other ->
        Logger.error("Non-existent msg_type: #{inspect(msg_type)}")
        []
    end
  end
end
