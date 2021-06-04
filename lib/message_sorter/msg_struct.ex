defmodule MessageSorter.MsgStruct do
  defstruct classification: nil, expiration_mono_ms: nil, value: nil

  def create_msg(classification, expiration_mono_ms, value) do
    %MessageSorter.MsgStruct{
      classification: classification,
      expiration_mono_ms: expiration_mono_ms,
      value: value
    }
  end
end
