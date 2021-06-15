defmodule Uart.TerarangerEvo do
  use Bitwise
  use GenServer
  require Logger
  require Uart.TerarangerEvo.Crc, as: Crc

  @max_range_expected 40.0
  @start_byte 84



  def start_link(config) do
    Logger.debug("Start Uart.TerarangerEvo")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    Comms.Supervisor.start_operator(__MODULE__)

    state = %{
      uart_ref: nil,
      range: nil,
      start_byte_found: false,
      remaining_buffer: [],
      new_range_data_to_publish: false
    }

    uart_port = Keyword.fetch!(config, :uart_port)
    port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
    GenServer.cast(self(), {:open_uart_connection, uart_port, port_options})
    Logger.debug("Uart.TerarangerEvo setup complete!")
    {:ok, state}
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
  def handle_cast({:open_uart_connection, uart_port, port_options}, state) do
    uart_ref =
      ViaUtils.Uart.open_connection_and_return_uart_ref(
        uart_port,
        port_options
      )

    {:noreply, %{state | uart_ref: uart_ref}}
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
      |> Bitwise.^^^(Enum.at(Crc.crc_table(), i))
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
