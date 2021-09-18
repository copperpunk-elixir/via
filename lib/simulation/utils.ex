defmodule Simulation.Utils do
  @sim_env_filename "simulator.txt"

  @spec get_simulation_env() :: tuple()
  def get_simulation_env() do
    [simulator_and_modelname] =
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

    [simulator, modelname] =
      if is_nil(simulator_and_modelname) do
        raise "Simulator environment could not be located"
      else
        String.split(simulator_and_modelname, ",")
      end

    {simulator, modelname}
  end

  @spec get_vehicle_and_model_type(binary(), binary()) :: tuple()
  def get_vehicle_and_model_type(simulator, modelname) do
    simulator_prefix =
      case simulator do
        "realflight" -> "Rf"
        "xplane" -> "Xp"
      end

    model_type = simulator_prefix <> String.capitalize(modelname)

    vehicle_type =
      case model_type do
        "XpSkyhawk" -> "FixedWing"
        "RfCessna2m" -> "FixedWing"
        other -> raise "#{other} model_type not recognized"
      end

    {vehicle_type, model_type}
  end
end
