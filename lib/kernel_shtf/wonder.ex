defmodule KernelShtf.Wonder do
  @moduledoc """
  A simplified implementation of GenServer behavior using macros.
  """

  @callback init(term) :: {:ok, term} | {:error, term}
  @callback handle_call(term, {pid, term}, term) :: {:reply, term, term}
  @callback handle_cast(term, term) :: {:noreply, term}
  @callback handle_info(term, term) :: {:noreply, term}

  defmacro __using__(_opts) do
    quote do
      @behaviour KernelShtf.Wonder

      # Explicitly import the macros
      require KernelShtf.Wonder.Macros
      import KernelShtf.Wonder.Macros

      def start_link(init_arg) do
        KernelShtf.Wonder.Server.start_link(__MODULE__, init_arg)
      end

      def child_spec(init_arg) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]},
          type: :worker,
          restart: :permanent,
          shutdown: 5000
        }
      end
    end
  end
end
