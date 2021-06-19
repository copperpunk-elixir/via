defmodule MessageSorter.DiscreteLooper.Member do
  require Logger

  defstruct process_id: nil, send_when_stale: false

  @spec new(any(), boolean()) :: struct()
  def new(process_id, send_when_state) do
    %MessageSorter.DiscreteLooper.Member{process_id: process_id, send_when_stale: send_when_state}
  end

  @spec new_send_current_only(any()) :: struct()
  def new_send_current_only(process_id) do
    new(process_id, false)
  end

  @spec new_send_current_or_stale(any()) :: struct()
  def new_send_current_or_stale(process_id) do
    new(process_id, true)
  end

  @spec send?(struct(), atom()) :: boolean()
  def send?(member, sorter_status) do
    if sorter_status == :current do
      true
    else
      member.send_when_stale
    end
  end
end
