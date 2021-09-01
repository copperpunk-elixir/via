defmodule Configuration.FixedWing.Cessna.Sim.Display do
  @spec config() :: list()
  def config() do
    gcs_scene = Display.Scenic.Gcs.FixedWing
    # Display.Scenic.Planner
    planner_scene = nil

    driver_module =
      if Via.Application.is_target() do
        Scenic.Driver.Nerves.Rpi
      else
        Scenic.Driver.Glfw
      end

    gcs_config = %{
      name: :main_viewport,
      size: {1024, 600},
      default_scene: {gcs_scene, nil},
      drivers: [
        %{
          module: driver_module,
          name: :gcs_driver,
          opts: [resizeable: false, title: "gcs"]
        }
      ]
    }

    # PLANNER
    planner_config = %{
      name: :planner,
      size: {1000, 1000},
      default_scene: {planner_scene, nil},
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
