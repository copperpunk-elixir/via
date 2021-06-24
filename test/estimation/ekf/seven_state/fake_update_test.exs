defmodule Estimation.Ekf.SevenState.FakeUpdateTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Run full EKF cycle", full_config do
    ekf_config = full_config[:Estimation][:Estimator][:kf_config]
    ekf = Estimation.Ekf.SevenState.new(ekf_config)
    position = ViaUtils.Location.new_location_input_degrees(42, -120, 123)
    velocity = %{north: 1.0, east: 0 * 2.0, down: 0 * -3.0}

    ekf =
      Estimation.Ekf.SevenState.update_from_gps(ekf, position, velocity)
      |> Estimation.Ekf.SevenState.update_from_heading(0.1)

    dt_accel_gyro = %{dt_s: 0.05, ax_mpss: 1.0, ay_mpss: 0, az_mpss: 0, gx_rps: 0.1, gy_rps: 0, gz_rps: 0}

    ekf =
      Enum.reduce(1..2000, ekf, fn _x, acc ->
        # start_time = :erlang.monotonic_time(:nanosecond)
        acc = Estimation.Ekf.SevenState.predict(acc, dt_accel_gyro)
        # end_time = :erlang.monotonic_time(:nanosecond)
        # IO.puts("predict dt: #{(end_time - start_time) * 1.0e-6}")
        acc
      end)

    IO.inspect(ekf)

    IO.puts(
      "position: #{ViaUtils.Location.to_string(Estimation.Ekf.SevenState.position_rrm(ekf))}"
    )

    {position, velocity} = Estimation.Ekf.SevenState.position_rrm_velocity_mps(ekf)
    IO.puts("position: #{ViaUtils.Location.to_string(position)}")
    IO.puts("velocity: #{ViaUtils.Format.eftb_map(velocity, 2)}")
  end
end
