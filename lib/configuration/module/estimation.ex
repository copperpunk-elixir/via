defmodule Configuration.Module.Estimation do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    [
      estimator: [
        imu_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        ins_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:fast),
        sca_values_slow_loop_interval_ms: Configuration.Generic.get_loop_interval_ms(:slow),
        accel_gyro_rate_expected_interval_ms: 5,
        gps_expected_interval_ms: 200,
        range_expected_interval_ms: 100,
      ]
    ]
  end
end
