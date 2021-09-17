defmodule Via.MixProject do
  use Mix.Project

  @app :via
  @version "0.1.0"
  @all_targets [:rpi, :rpi0, :rpi3, :rpi3a, :rpi4]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.12",
      archives: [nerves_bootstrap: "~> 1.10"],
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Via.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.7.11", runtime: false},
      {:shoehorn, "~> 0.7.0"},
      {:ring_logger, "~> 0.8.1"},
      {:toolshed, "~> 0.2.13"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.11.3", targets: @all_targets},
      {:nerves_pack, "~> 0.4.2", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi, "~> 1.16.2", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.16.2", runtime: false, targets: :rpi0},
      {:nerves_system_rpi3, "~> 1.16.2", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.16.2", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.16.2", runtime: false, targets: :rpi4},
      # Scenic dependencies
      {:scenic, "~> 0.10.5"},
      {:scenic_driver_glfw, "~> 0.10.1", targets: :host},
      {:scenic_driver_nerves_rpi, "0.10.0", targets: @all_targets},
      {:scenic_driver_nerves_touch, "0.10.0", targets: @all_targets},
      {:scenic_sensor, "~> 0.7"},
      {:circuits_uart, "~> 1.4.2"},
      {:vintage_net, "~> 0.10.5", targets: @all_targets},
      {:vintage_net_wifi, "~> 0.10.5", targets: @all_targets},
      {:vintage_net_ethernet, "~> 0.10.2", targets: @all_targets},
      # COPPERPUNK packages
      # ~> 0.1.0"},
      {:ubx_interpreter,
       git: "https://github.com/copperpunk-elixir/ubx-interpreter.git", tag: "v0.1.0-alpha.1"},
      # "~> 0.1.0"},
      {:frsky_parser,
       git: "https://github.com/copperpunk-elixir/frsky-parser.git", tag: "v0.1.0-alpha"},
      # "~> 0.1.1"},
      {:dsm_parser,
       git: "https://github.com/copperpunk-elixir/dsm-parser.git", tag: "v0.1.1-alpha"},
      # "~> 0.1.4"},
      {:via_utils, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/via-utils", override: true},
      #  git: "https://github.com/copperpunk-elixir/via-utils.git", tag: "v0.1.4-alpha"},
      # ~> 0.1.1"},
      {:via_controllers,
       git: "https://github.com/copperpunk-elixir/via-controllers.git", tag: "v0.1.1-alpha.1"},
      # "~> 0.1.2"},
      {:xplane_integration,
       git: "https://github.com/copperpunk-elixir/xplane-integration.git", tag: "v0.1.3-alpha.1"},
      # "~> 0.1.1"},
      {:realflight_integration, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/realflight-integration"},
      #  git: "https://github.com/copperpunk-elixir/realflight-integration.git", tag: "v0.1.1-alpha"},
      {:via_estimation,
       git: "https://github.com/copperpunk-elixir/via-estimation.git", tag: "v0.1.1-alpha.1"},
      # "~> 0.1.0"},
      {:via_input_event, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/via-input-event"},

      #  git: "https://github.com/copperpunk-elixir/via-input-event.git", tag: "v0.1.0-alpha.1"}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://hexdocs.pm/nerves_pack/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end
