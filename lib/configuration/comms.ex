defmodule Configuration.Module.Comms do
  @spec get_config(binary(), binary()) :: list()
  def get_config(_model_type, _node_type) do
    []
  end
end
