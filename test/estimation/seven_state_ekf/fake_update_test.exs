defmodule Estimation.SevenStateEkf.FakeSevenStateUpdateTest do
  use ExUnit.Case
  require Logger

  setup do
    {model_type, node_type} = Common.Application.start_test()
    {:ok, [model_type: model_type, node_type: node_type]}
  end

  test "Run full EKF cycle" do
    ekf = SevenStateEkf.new()
    position = Common.Utils.LatLonAlt.new_deg(42, -120, 123)
    velocity = %{north: 1.0, east: 0 * 2.0, down: 0 * -3.0}

    ekf =
      SevenStateEkf.update_from_gps(ekf, position, velocity)
      |> SevenStateEkf.update_from_heading(0.1)

    dt_accel_gyro = [0.05, 1.0, 0, 0, 0.1, 0, 0]

    ekf =
      Enum.reduce(1..2000, ekf, fn _x, acc ->
        start_time = :erlang.monotonic_time(:nanosecond)
        acc = SevenStateEkf.predict(acc, dt_accel_gyro)
        end_time = :erlang.monotonic_time(:nanosecond)
        # IO.puts("predict dt: #{(end_time - start_time) * 1.0e-6}")
        acc
      end)

    IO.inspect(ekf)
    IO.puts("position: #{Common.Utils.LatLonAlt.to_string(SevenStateEkf.position_rrm(ekf))}")
    {position, velocity} = SevenStateEkf.position_rrm_velocity_mps(ekf)
    IO.puts("position: #{Common.Utils.LatLonAlt.to_string(position)}")
    IO.puts("velocity: #{Common.Utils.eftb_map(velocity, 2)}")
  end
end
