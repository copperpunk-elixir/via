defmodule Uart.TerarangerEvo do
  use Bitwise
  use GenServer
  require Logger

  @max_range_expected 40.0
  @start_byte 84

  @crc_table {
    0x00,
    0x07,
    0x0E,
    0x09,
    0x1C,
    0x1B,
    0x12,
    0x15,
    0x38,
    0x3F,
    0x36,
    0x31,
    0x24,
    0x23,
    0x2A,
    0x2D,
    0x70,
    0x77,
    0x7E,
    0x79,
    0x6C,
    0x6B,
    0x62,
    0x65,
    0x48,
    0x4F,
    0x46,
    0x41,
    0x54,
    0x53,
    0x5A,
    0x5D,
    0xE0,
    0xE7,
    0xEE,
    0xE9,
    0xFC,
    0xFB,
    0xF2,
    0xF5,
    0xD8,
    0xDF,
    0xD6,
    0xD1,
    0xC4,
    0xC3,
    0xCA,
    0xCD,
    0x90,
    0x97,
    0x9E,
    0x99,
    0x8C,
    0x8B,
    0x82,
    0x85,
    0xA8,
    0xAF,
    0xA6,
    0xA1,
    0xB4,
    0xB3,
    0xBA,
    0xBD,
    0xC7,
    0xC0,
    0xC9,
    0xCE,
    0xDB,
    0xDC,
    0xD5,
    0xD2,
    0xFF,
    0xF8,
    0xF1,
    0xF6,
    0xE3,
    0xE4,
    0xED,
    0xEA,
    0xB7,
    0xB0,
    0xB9,
    0xBE,
    0xAB,
    0xAC,
    0xA5,
    0xA2,
    0x8F,
    0x88,
    0x81,
    0x86,
    0x93,
    0x94,
    0x9D,
    0x9A,
    0x27,
    0x20,
    0x29,
    0x2E,
    0x3B,
    0x3C,
    0x35,
    0x32,
    0x1F,
    0x18,
    0x11,
    0x16,
    0x03,
    0x04,
    0x0D,
    0x0A,
    0x57,
    0x50,
    0x59,
    0x5E,
    0x4B,
    0x4C,
    0x45,
    0x42,
    0x6F,
    0x68,
    0x61,
    0x66,
    0x73,
    0x74,
    0x7D,
    0x7A,
    0x89,
    0x8E,
    0x87,
    0x80,
    0x95,
    0x92,
    0x9B,
    0x9C,
    0xB1,
    0xB6,
    0xBF,
    0xB8,
    0xAD,
    0xAA,
    0xA3,
    0xA4,
    0xF9,
    0xFE,
    0xF7,
    0xF0,
    0xE5,
    0xE2,
    0xEB,
    0xEC,
    0xC1,
    0xC6,
    0xCF,
    0xC8,
    0xDD,
    0xDA,
    0xD3,
    0xD4,
    0x69,
    0x6E,
    0x67,
    0x60,
    0x75,
    0x72,
    0x7B,
    0x7C,
    0x51,
    0x56,
    0x5F,
    0x58,
    0x4D,
    0x4A,
    0x43,
    0x44,
    0x19,
    0x1E,
    0x17,
    0x10,
    0x05,
    0x02,
    0x0B,
    0x0C,
    0x21,
    0x26,
    0x2F,
    0x28,
    0x3D,
    0x3A,
    0x33,
    0x34,
    0x4E,
    0x49,
    0x40,
    0x47,
    0x52,
    0x55,
    0x5C,
    0x5B,
    0x76,
    0x71,
    0x78,
    0x7F,
    0x6A,
    0x6D,
    0x64,
    0x63,
    0x3E,
    0x39,
    0x30,
    0x37,
    0x22,
    0x25,
    0x2C,
    0x2B,
    0x06,
    0x01,
    0x08,
    0x0F,
    0x1A,
    0x1D,
    0x14,
    0x13,
    0xAE,
    0xA9,
    0xA0,
    0xA7,
    0xB2,
    0xB5,
    0xBC,
    0xBB,
    0x96,
    0x91,
    0x98,
    0x9F,
    0x8A,
    0x8D,
    0x84,
    0x83,
    0xDE,
    0xD9,
    0xD0,
    0xD7,
    0xC2,
    0xC5,
    0xCC,
    0xCB,
    0xE6,
    0xE1,
    0xE8,
    0xEF,
    0xFA,
    0xFD,
    0xF4,
    0xF3
  }

  def start_link(config) do
    Logger.debug("Start Uart.TerarangerEvo")
    {:ok, pid} = ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    unless is_nil(Map.get(state, :uart_ref)) do
      Circuits.UART.close(state.uart_ref)
    end

    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config}, _state) do
    Comms.Supervisor.start_operator(__MODULE__)

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    uart_ref = ViaUtils.Uart.open_connection_and_return_uart_ref(uart_port, port_options)

    state = %{
      uart_ref: uart_ref,
      range: nil,
      start_byte_found: false,
      remaining_buffer: [],
      new_range_data_to_publish: false
    }

    Logger.debug("Uart.TerarangerEvo setup complete!")
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:write, range}, state) do
    msg = create_message_for_range_m(range) |> :binary.list_to_bin()
    Circuits.UART.write(state.uart_ref, msg)
    #    Circuits.UART.drain(state.uart_ref)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("evo received: #{data}")
    data_list = state.remaining_buffer ++ :binary.bin_to_list(data)
    state = parse_data_buffer(data_list, state)

    state =
      if state.new_range_data_to_publish do
        Comms.Operator.send_global_msg_to_group(
          __MODULE__,
          {{:estimation_measured, :range}, state.range},
          self()
        )

        %{state | new_range_data_to_publish: false}
      else
        state
      end

    {:noreply, state}
  end

  @spec parse_data_buffer(list(), map()) :: map()
  def parse_data_buffer(entire_buffer, state) do
    {valid_buffer, start_byte_found} =
      if !state.start_byte_found do
        # A start byte has not been found yet. Search for it
        start_byte_index = Enum.find_index(entire_buffer, fn x -> x == @start_byte end)

        if start_byte_index == nil do
          # No start byte in the entire buffer, throw it all away
          {[], false}
        else
          # The buffer contains a start byte
          # Throw out everything before the start byte
          {_removed, valid_buffer} = Enum.split(entire_buffer, start_byte_index)
          {valid_buffer, true}
        end
      else
        # There is a valid start byte leftover from the last read
        {entire_buffer, true}
      end

    if start_byte_found do
      # The valid buffer should contain only the bytes after (and including) the start byte
      crc_calculation_buffer_and_remaining = valid_buffer

      {payload_buffer, crc_and_remaining_buffer} =
        Enum.split(crc_calculation_buffer_and_remaining, 3)

      # This could be a good message
      # The CRC is contained in the byte immediately following the payload
      {state, parse_again} =
        unless Enum.empty?(crc_and_remaining_buffer) do
          crc_calc_value = calculate_checksum(payload_buffer)

          if crc_calc_value == Enum.at(crc_and_remaining_buffer, 0) do
            # Good Checksum, drop entire message before we parse the next time
            # We can leave the CRC bytes attached to the end of the payload buffer, because we know the length
            # The remaining_buffer is everything after the CRC bytes
            remaining_buffer = Enum.drop(crc_and_remaining_buffer, 1)
            {range, valid} = parse_good_message(Enum.drop(payload_buffer, 1))
            # Logger.debug("range: #{range}/#{valid}")
            state = %{
              state
              | remaining_buffer: remaining_buffer,
                start_byte_found: false,
                range: range,
                new_range_data_to_publish: valid
            }

            {state, true}
          else
            # Bad checksum, which doesn't mean we lost some data
            # It could just mean that our "start byte" was just a data byte, so only
            # Drop the start byte before we parse next
            remaining_buffer = Enum.drop(valid_buffer, 1)
            state = %{state | remaining_buffer: remaining_buffer, start_byte_found: false}
            {state, true}
          end
        else
          # We have not received enough data to parse a complete message
          # The next loop should try again with the same start_byte
          state = %{state | remaining_buffer: valid_buffer, start_byte_found: true}
          {state, false}
        end

      if parse_again do
        parse_data_buffer(state.remaining_buffer, state)
      else
        state
      end
    else
      %{state | start_byte_found: false}
    end
  end

  @spec calculate_checksum(list()) :: integer()
  def calculate_checksum(buffer) do
    crc = 0

    Enum.reduce(Enum.take(buffer, 3), 0, fn x, acc ->
      i = Bitwise.^^^(acc, x) |> Bitwise.&&&(0xFF)

      Bitwise.<<<(crc, 8)
      |> Bitwise.^^^(elem(@crc_table, i))
      |> Bitwise.&&&(0xFF)
    end)
  end

  @spec parse_good_message(list()) :: {integer(), boolean()}
  def parse_good_message(buffer) do
    # Logger.debug("payload buffer: #{inspect(buffer)}")
    range = Bitwise.<<<(Enum.at(buffer, 0), 8) + Enum.at(buffer, 1)

    if range == 0xFFFF do
      {0, false}
    else
      {range * 0.001, true}
    end
  end

  @spec create_message_for_range_mm(integer()) :: list()
  def create_message_for_range_mm(range) do
    {msb, lsb} =
      if range < 60000 do
        msb = Bitwise.>>>(range, 8)
        lsb = Bitwise.&&&(range, 0xFF)
        {msb, lsb}
      else
        {0xFF, 0xFF}
      end

    buffer = [@start_byte, msb, lsb]
    crc = calculate_checksum(buffer)
    buffer ++ [crc]
  end

  @spec create_message_for_range_m(float()) :: list()
  def create_message_for_range_m(range) do
    (range * 1000) |> round() |> create_message_for_range_mm()
  end

  @spec publish_range(float()) :: atom()
  def publish_range(range) do
    GenServer.cast(__MODULE__, {:write, range})
  end

  @spec max_range() :: float()
  def max_range() do
    @max_range_expected
  end
end
