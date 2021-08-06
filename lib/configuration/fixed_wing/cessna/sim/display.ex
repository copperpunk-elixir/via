defmodule Configuration.FixedWing.Cessna.Sim.Display do
  @spec config() :: list()
  def config() do
    gcs_scene = Display.Scenic.Gcs.FixedWing
    planner_scene = nil #Display.Scenic.Planner

    gcs_config = %{
      name: :gcs,
      size: {900, 800},
      default_scene: {gcs_scene, nil},
      drivers: [
        %{
          module: Scenic.Driver.Glfw,
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
          module: Scenic.Driver.Glfw,
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
