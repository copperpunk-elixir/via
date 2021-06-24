defmodule Estimation.PublishEstimationValues do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU
  alias TestHelper.Estimation.GenServer, as: TEG

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Publish All Values", full_config do
    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = full_config[:Uart][:Companion]
    Uart.Companion.start_link(config)
    Process.sleep(200)

    config = full_config[:Uart][:Gps]
    Uart.Gps.start_link(config)
    Process.sleep(200)

    TEG.start_link()
    Process.sleep(200)
    assert !is_nil(TEG.get_value_for_key(:attitude_rad))

    Enum.each(1..500, fn _x ->
      attitude_rad = TEG.get_value_for_key(:attitude_rad)
      position_rrm = TEG.get_value_for_key(:position_rrm)
      groundspeed_mps = TEG.get_value_for_key(:groundspeed_mps)
      course_rad = TEG.get_value_for_key(:course_rad)
      airspeed_mps = TEG.get_value_for_key(:airspeed_mps)

      Logger.debug("Attitude: #{VU.Format.eftb_map_deg(attitude_rad, 1)}")

      Logger.debug("position_rrm: #{VU.Location.to_string(position_rrm)}")

      Logger.debug(
        "speed/course/AS/dt: #{VU.Format.eftb(groundspeed_mps, 1)}/#{VU.Format.eftb_deg(course_rad, 1)}/#{
          VU.Format.eftb(airspeed_mps, 1)
        }"
      )
      Process.sleep(20)
    end)
  end
end
