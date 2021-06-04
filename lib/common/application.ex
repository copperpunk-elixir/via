defmodule Common.Application do
  use Application
  require Logger

  def start(_type, _args) do
    {:ok, self()}
  end

  @spec start_test(binary(), binary()) :: atom()
  def start_test(model_type \\ "Cessna", node_type \\ "sim") do
    prepare_environment()
    Boss.System.start_universal_modules(model_type, node_type)
    {model_type, node_type}
  end

  @spec prepare_environment() :: atom()
  def prepare_environment() do
    define_atoms()
    # if Common.Utils.is_target?() do
      RingLogger.attach()
    # end
  end

  @spec define_atoms() :: atom()
  def define_atoms() do
    atoms_as_strings = [
      "Plane",
      "Multirotor",
      "Car",
      "Cessna",
      "CessnaZ2m",
      "T28",
      "T28Z2m",
      "QuadX",
      "FerrariF1",
      "Ina260",
      "Ina219",
      "Sixfab",
      "Atto90"
    ]
    Enum.each(atoms_as_strings, fn x ->
      String.to_atom(x)
    end)
  end
end
