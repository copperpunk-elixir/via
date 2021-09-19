defmodule Configuration.Xplane.FixedWing.Skyhawk.Sim.Display do
  @spec config() :: list()
  def config() do
    gcs_scene = Display.Scenic.Gcs.FixedWing
    # Display.Scenic.Planner
    planner_scene = nil

    driver_module =
      if ViaUtils.File.target?() do
        Scenic.Driver.Nerves.Rpi
      else
        Scenic.Driver.Glfw
      end

    gcs_drivers =
      if ViaUtils.File.target?() do
        [
          %{
            module: driver_module,
            name: :gcs_driver,
            opts: [resizeable: false, title: "gcs"]
          },
          %{
            module: Scenic.Driver.Nerves.Touch,
            opts: [
              device: "raspberrypi-ts",
              calibration: {{1, 0, 0}, {1, 0, 0}}
            ]
          }
        ]
      else
        [%{
          module: driver_module,
          name: :gcs_driver,
          opts: [resizeable: false, title: "gcs"]
        }]
      end

    gcs_config = %{
      name: :main_viewport,
      size: {800, 480},
      default_scene: {gcs_scene, %{show_realflight_ip: false}},
      drivers: gcs_drivers
    }

    # PLANNER
    planner_config = %{
      name: :planner,
      size: {1000, 1000},
      default_scene: {planner_scene, %{}},
      drivers: [
        %{
          module: driver_module,
          name: :planner_driver,
          opts: [resizeable: false, title: "planner"]
        }
      ]
    }

    viewports = if is_nil(planner_scene), do: [gcs_config], else: [gcs_config, planner_config]

    [
      viewports: viewports
    ]
  end
end
