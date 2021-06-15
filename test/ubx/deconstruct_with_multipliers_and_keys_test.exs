defmodule Ubx.DeconstructWithMultipliersAndKeys do
  use ExUnit.Case
  require Logger
  require Ubx.NavRelposned, as: NavRelposned

  setup do
    RingLogger.attach()
    {:ok, []}
  end

  test "Deconstruct NavPvt" do
    values =
      [
        1,
        2,
        1000,
        1.0e6,
        -1.0e-6,
        -2.0e-6,
        -3.0e-6,
        -4.0e-6,
        5.0e-6,
        12_345_678,
        -1,
        -2,
        -3,
        4,
        5,
        5,
        5,
        5,
        5,
        5,
        6
      ]
      |> Enum.map(fn x -> round(x) end)

    {msg_class, msg_id} = NavRelposned.class_id()
    msg = UbxInterpreter.Utils.construct_message(msg_class, msg_id, NavRelposned.bytes(), values)

    ubx = UbxInterpreter.new()
    {_ubx, payload_rx} = UbxInterpreter.check_for_new_message(ubx, :binary.bin_to_list(msg))

    multipliers = NavRelposned.multipliers()
    keys = NavRelposned.keys()

    values_rx =
      UbxInterpreter.Utils.deconstruct_message(
        NavRelposned.bytes(),
        multipliers,
        keys,
        payload_rx
      )

    Logger.debug("rx: #{inspect(values_rx)}")

    Enum.each(values_rx, fn {key, value} ->
      key_index = Enum.find_index(keys, fn x -> key == x end)
      assert_in_delta(value, Enum.at(values, key_index) * Enum.at(multipliers, key_index), 0.001)
    end)
  end
end
