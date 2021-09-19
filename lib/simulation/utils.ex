defmodule Simulation.Utils do
  require ViaUtils.File
  require Logger

  @sim_env_filename "simulation.txt"

  @spec get_simulation_env(binary(), binary(), binary()) :: tuple()
  def get_simulation_env(
        default_sim_name \\ "",
        default_model_name \\ "",
        default_input_type \\ ""
      ) do
    file_contents =
      if ViaUtils.File.target?() do
        ViaUtils.File.read_file_target(
          @sim_env_filename,
          ViaUtils.File.default_mount_path(),
          true,
          true
        )
      else
        ViaUtils.File.read_file(
          @sim_env_filename,
          ViaUtils.File.default_mount_path(),
          true
        )
      end

    [simulator_name, model_name, input_type] =
      cond do
        is_nil(file_contents) ->
          Logger.warn("Simulator environment could not be located.")

          Logger.warn(
            "Using defaults of #{default_sim_name}/#{default_model_name}/#{default_input_type}"
          )

          [default_sim_name, default_model_name, default_input_type]

        length(String.split(file_contents, ",")) == 3 ->
          String.split(file_contents, ",")

        length(String.split(file_contents, ",")) == 2 ->
          [simulator_name, model_name] = String.split(file_contents, ",")
          simulator_name = String.downcase(simulator_name)

          case simulator_name do
            "realflight" -> [simulator_name, model_name, "none"]
            "xplane" -> [simulator_name, model_name, "any"]
          end
      end

    simulator_type = String.capitalize(simulator_name)
    model_type = String.capitalize(model_name)
    {simulator_type, model_type, input_type}
  end

  @spec get_vehicle_type(binary()) :: tuple()
  def get_vehicle_type(model_type) do
    vehicle_type =
      case model_type do
        "Skyhawk" -> "FixedWing"
        "Cessna2m" -> "FixedWing"
        other -> raise "#{other} model_type not recognized"
      end

    vehicle_type
  end

  # def get_simulator_type_from_name(simulator_name) do
  #   Enum.reduce(String.split(simulator_name, "_"), "", fn word, acc ->
  #     acc <> String.capitalize(word)
  #   end)
  # end
end
