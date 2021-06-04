defmodule Configuration.Module.Peripherals.Leds do
  require Logger
  @spec get_config(atom(), atom()) :: map()
  def get_config(_model_type, _node_type) do
    [
      Status: [
        leds: [
          %{name: "led0", on_duration_ms: 100, off_duration_ms: 900}
        ]
      ]
    ]
  end
end
