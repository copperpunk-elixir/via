defmodule Comms.ProcessRegistry do
  require Logger

  def start_link do
    Logger.debug("Start ProcessRegistry")
    Common.Utils.start_link_redundant(Registry, Registry, [keys: :unique, name: __MODULE__])
  end

  def terminate(reason, state) do
    Logging.Logger.log_terminate(reason, state, __MODULE__)
    state
  end

  def via_tuple(process_module, process_name) do
    key = get_key_for_module_and_name(process_module, process_name)
    {:via, Registry, {__MODULE__, key}}
  end

  def get_key_for_module_and_name(process_module, process_name) do
    case process_name do
      nil -> {process_module, process_module}
      _valid_name -> {process_module, process_name}
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
