defmodule Counter do
  use KernelShtf.Wonder

  # Define initial state
  magic do
    %{count: 0}
  end

  # Define synchronous calls
  force(:get_count, []) do
    state.count
  end

  force(:increment, [amount]) do
    new_count = state.count + amount
    %{state | count: new_count}
  end

  # Define asynchronous casts
  spell(:reset, []) do
    %{state | count: 0}
  end

  # Handle unexpected messages
  def handle_info(_msg, state), do: {:noreply, state}
end
