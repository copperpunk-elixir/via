defmodule Logging.Logger do
  require Logger
  def log_terminate(reason, state, module) do
    Logger.debug("#{module} terminated for #{inspect(reason)} with state #{inspect(state)}")
  end
end
