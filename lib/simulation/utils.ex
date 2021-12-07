defmodule Simulation.Utils do
  require ViaUtils.File
  require Logger
  require Configuration.Filenames, as: Filenames

  @spec get_simulation_env(binary(), binary()) :: tuple()
  def get_simulation_env(
        default_model_name \\ "",
        default_input_type \\ ""
      ) do
    file_contents =
      if ViaUtils.File.target?() do
        ViaUtils.File.read_file_target(
          Filenames.simulation(),
          ViaUtils.File.default_mount_path(),
          true,
          true
        )
      else
        ViaUtils.File.read_file(
          Filenames.simulation(),
          ViaUtils.File.default_mount_path(),
          true
        )
      end

    [model_name, input_type] =
      cond do
        is_nil(file_contents) ->
          Logger.warn("Simulator environment could not be located.")

          Logger.warn(
            "Using defaults of #{default_model_name}/#{default_input_type}"
          )

          [default_model_name, default_input_type]

        length(String.split(file_contents, ",")) == 2 ->
          String.split(file_contents, ",")

        length(String.split(file_contents, ",")) == 1 ->
          model_name = String.downcase(file_contents)
          simulator_name = get_simulator_name(model_name)
          Logger.warn("simulator name: #{simulator_name}")
          case simulator_name do
            "realflight" -> [model_name, "none"]
            "xplane" -> [model_name, "any"]
          end
      end

    model_type = String.capitalize(model_name)
    {model_type, input_type}
  end

  @spec get_vehicle_type(binary()) :: binary()
  def get_vehicle_type(model_type) do
    case model_type do
      "Skyhawk" -> "FixedWing"
      "Cessna2m" -> "FixedWing"
      other -> raise "#{other} model_type not recognized"
    end
  end

  @spec get_simulator_name(binary()) :: binary()
  def get_simulator_name(model_name) do
    case model_name do
      "skyhawk" -> "xplane"
      "cessna2m" -> "realflight"
      other -> raise "#{other} model_type not recognized"
    end
  end
end
