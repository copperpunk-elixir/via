defmodule Peripherals.Uart.Estimation.TerarangerEvo.Operator do
  use Bitwise
  use GenServer
  require Logger

  @max_range_expected 40.0
  @start_byte 84

  @crc_table {
 0x00, 0x07, 0x0e, 0x09, 0x1c, 0x1b, 0x12, 0x15, 0x38, 0x3f, 0x36, 0x31,
  0x24, 0x23, 0x2a, 0x2d, 0x70, 0x77, 0x7e, 0x79, 0x6c, 0x6b, 0x62, 0x65,
  0x48, 0x4f, 0x46, 0x41, 0x54, 0x53, 0x5a, 0x5d, 0xe0, 0xe7, 0xee, 0xe9,
  0xfc, 0xfb, 0xf2, 0xf5, 0xd8, 0xdf, 0xd6, 0xd1, 0xc4, 0xc3, 0xca, 0xcd,
  0x90, 0x97, 0x9e, 0x99, 0x8c, 0x8b, 0x82, 0x85, 0xa8, 0xaf, 0xa6, 0xa1,
  0xb4, 0xb3, 0xba, 0xbd, 0xc7, 0xc0, 0xc9, 0xce, 0xdb, 0xdc, 0xd5, 0xd2,
  0xff, 0xf8, 0xf1, 0xf6, 0xe3, 0xe4, 0xed, 0xea, 0xb7, 0xb0, 0xb9, 0xbe,
  0xab, 0xac, 0xa5, 0xa2, 0x8f, 0x88, 0x81, 0x86, 0x93, 0x94, 0x9d, 0x9a,
  0x27, 0x20, 0x29, 0x2e, 0x3b, 0x3c, 0x35, 0x32, 0x1f, 0x18, 0x11, 0x16,
  0x03, 0x04, 0x0d, 0x0a, 0x57, 0x50, 0x59, 0x5e, 0x4b, 0x4c, 0x45, 0x42,
  0x6f, 0x68, 0x61, 0x66, 0x73, 0x74, 0x7d, 0x7a, 0x89, 0x8e, 0x87, 0x80,
  0x95, 0x92, 0x9b, 0x9c, 0xb1, 0xb6, 0xbf, 0xb8, 0xad, 0xaa, 0xa3, 0xa4,
  0xf9, 0xfe, 0xf7, 0xf0, 0xe5, 0xe2, 0xeb, 0xec, 0xc1, 0xc6, 0xcf, 0xc8,
  0xdd, 0xda, 0xd3, 0xd4, 0x69, 0x6e, 0x67, 0x60, 0x75, 0x72, 0x7b, 0x7c,
  0x51, 0x56, 0x5f, 0x58, 0x4d, 0x4a, 0x43, 0x44, 0x19, 0x1e, 0x17, 0x10,
  0x05, 0x02, 0x0b, 0x0c, 0x21, 0x26, 0x2f, 0x28, 0x3d, 0x3a, 0x33, 0x34,
  0x4e, 0x49, 0x40, 0x47, 0x52, 0x55, 0x5c, 0x5b, 0x76, 0x71, 0x78, 0x7f,
  0x6a, 0x6d, 0x64, 0x63, 0x3e, 0x39, 0x30, 0x37, 0x22, 0x25, 0x2c, 0x2b,
  0x06, 0x01, 0x08, 0x0f, 0x1a, 0x1d, 0x14, 0x13, 0xae, 0xa9, 0xa0, 0xa7,
  0xb2, 0xb5, 0xbc, 0xbb, 0x96, 0x91, 0x98, 0x9f, 0x8a, 0x8d, 0x84, 0x83,
  0xde, 0xd9, 0xd0, 0xd7, 0xc2, 0xc5, 0xcc, 0xcb, 0xe6, 0xe1, 0xe8, 0xef,
  0xfa, 0xfd, 0xf4, 0xf3}

  def start_link(config) do
    Logger.debug("Start Uart.Estimation.TerarangerEvo.Operator")
    {:ok, pid} = Common.Utils.start_link_redundant(GenServer,__MODULE__, nil, __MODULE__)
    GenServer.cast(__MODULE__, {:begin, config})
    {:ok, pid}
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  @impl GenServer
  def handle_cast({:begin, config} , _state) do
    Comms.System.start_operator(__MODULE__)

    {:ok, uart_ref} = Circuits.UART.start_link()
    state = %{
      uart_ref: uart_ref,
      range: nil,
      start_byte_found: false,
      remaining_buffer: [],
      new_range_data_to_publish: false
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]

    Peripherals.Uart.Utils.open_interface_connection_infinite(state.uart_ref, uart_port, port_options)
    Logger.debug("Uart.Estimation.TerarangerEvo.Operator setup complete!")
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
    state = if (state.new_range_data_to_publish) do
      Comms.Operator.send_global_msg_to_group(__MODULE__, {{:estimation_measured, :range}, state.range}, self())
      %{state | new_range_data_to_publish: false}
    else
      state
    end
    {:noreply, state}
  end

  @spec parse_data_buffer(list(), map()) :: map()
  def parse_data_buffer(entire_buffer, state) do
    {valid_buffer, start_byte_found} =
    if (!state.start_byte_found) do
      # A start byte has not been found yet. Search for it
      start_byte_index = Enum.find_index(entire_buffer, fn x -> x==@start_byte end)
      if start_byte_index == nil do
        # No start byte in the entire buffer, throw it all away
        {[], false}
      else
        # The buffer contains a start byte
        # Throw out everything before the start byte
        {_removed, valid_buffer} = Enum.split(entire_buffer,start_byte_index)
        {valid_buffer, true}
      end
    else
      # There is a valid start byte leftover from the last read
      {entire_buffer, true}
    end
    if start_byte_found do
      # The valid buffer should contain only the bytes after (and including) the start byte
      crc_calculation_buffer_and_remaining = valid_buffer
      {payload_buffer, crc_and_remaining_buffer} = Enum.split(crc_calculation_buffer_and_remaining,3)
      {state, parse_again} =
      # This could be a good message
      # The CRC is contained in the byte immediately following the payload
        unless Enum.empty?(crc_and_remaining_buffer) do
        crc_calc_value = calculate_checksum(payload_buffer)
        if (crc_calc_value == Enum.at(crc_and_remaining_buffer,0)) do
          # Good Checksum, drop entire message before we parse the next time
          # We can leave the CRC bytes attached to the end of the payload buffer, because we know the length
          # The remaining_buffer is everything after the CRC bytes
          remaining_buffer = Enum.drop(crc_and_remaining_buffer,1)
          {range, valid} = parse_good_message(Enum.drop(payload_buffer,1))
          # Logger.debug("range: #{range}/#{valid}")
          state = %{state |
                    remaining_buffer: remaining_buffer,
                    start_byte_found: false,
                    range: range,
                    new_range_data_to_publish: valid}
          {state, true}
        else
          # Bad checksum, which doesn't mean we lost some data
          # It could just mean that our "start byte" was just a data byte, so only
          # Drop the start byte before we parse next
          remaining_buffer = Enum.drop(valid_buffer,1)
          state = %{state |
                    remaining_buffer: remaining_buffer,
                    start_byte_found: false}
          {state, true}
        end
      else
        # We have not received enough data to parse a complete message
        # The next loop should try again with the same start_byte
        state = %{state |
                  remaining_buffer: valid_buffer,
                  start_byte_found: true}
        {state, false}
      end
      if (parse_again) do
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
    Enum.reduce(Enum.take(buffer,3),0,fn (x,acc) ->
      i = Bitwise.^^^(acc, x) |> Bitwise.&&&(0xFF)
      Bitwise.<<<(crc,8)
      |> Bitwise.^^^(elem(@crc_table,i))
      |> Bitwise.&&&(0xFF)
    end)
  end

  @spec parse_good_message(list()) :: {integer(), boolean()}
  def parse_good_message(buffer) do
    # Logger.debug("payload buffer: #{inspect(buffer)}")
    range = Bitwise.<<<(Enum.at(buffer,0),8) + Enum.at(buffer,1)
    if (range == 0xFFFF) do
      {0, false}
    else
      {range*0.001, true}
    end
  end

  @spec create_message_for_range_mm(integer()) :: list()
  def create_message_for_range_mm(range) do
    {msb, lsb} =
    if (range < 60000) do
    msb = Bitwise.>>>(range,8)
    lsb = Bitwise.&&&(range,0xFF)
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
    range*1000 |> round() |> create_message_for_range_mm()
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
