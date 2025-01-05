defmodule Counter do
  use RegServer

  # Define initial state
  defstate do
    %{count: 0}
  end

  # Define synchronous calls
  defcall(:get_count, []) do
    state.count
  end

  defcall(:increment, [amount]) do
    new_count = state.count + amount
    %{state | count: new_count}
  end

  # Define asynchronous casts
  defcast(:reset, []) do
    %{state | count: 0}
  end

  # Handle unexpected messages
  def handle_info(_msg, state), do: {:noreply, state}
end
