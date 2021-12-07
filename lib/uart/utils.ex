defmodule Uart.Utils do
  require Logger
  @spec config(module(), list()) :: list()
  def config(model_root_module, peripherals) do
    Logger.debug("peripherals: #{inspect(peripherals)}")

    Enum.reduce(peripherals, [], fn peripheral, acc ->
      [uart_module, port] = String.split(peripheral, "_")
      module_config = get_config(model_root_module, uart_module, port)
      module_key = Module.concat([uart_module])
      Keyword.put(acc, module_key, module_config)
    end)
  end

  @spec get_config(module(), binary(), binary()) :: tuple()
  def get_config(model_root_module, uart_module, port) do
    # Logger.debug("port: #{port}")
    uart_port =
      case port do
        "0" -> "ttyAMA0"
        "3" -> "ttyAMA1"
        "4" -> "ttyAMA2"
        "5" -> "ttyAMA3"
        _usb -> port
      end

    generic_config_module = Module.concat(__MODULE__, uart_module)
    generic_config = apply(generic_config_module, :config, [uart_port])
 Logger.debug("GCM: #{generic_config_module}")
    Logger.debug("GC: #{inspect(generic_config)}")

    model_specific_module = Module.concat(model_root_module, uart_module)

    model_specific_config =
      if Code.ensure_loaded?(model_specific_module) do
        apply(model_specific_module, :config, [])
      else
        []
      end
    Logger.debug("MSM: #{model_specific_module}")
    Logger.debug("msc: #{inspect(model_specific_config)}")
    ViaUtils.Configuration.merge_configuration_files(generic_config, model_specific_config)
  end
end
