defmodule KernelShtf.Mil do
  @moduledoc """
  A simplified implementation of GenServer behavior using macros with a clean DSL.
  Mil is short for thousand or military and is mechanized similar to a floppy disk drive.
  """

  @callback init(term) :: {:ok, term} | {:error, term}
  @callback handle_call(term, {pid, term}, term) :: {:reply, term, term}
  @callback handle_cast(term, term) :: {:noreply, term}
  @callback handle_info(term, term) :: {:noreply, term}

  defmacro __using__(_opts) do
    quote do
      @behaviour KernelShtf.Mil

      # Explicitly import the macros
      require KernelShtf.Mil.Macros
      import KernelShtf.Mil.Macros

      def start_link(init_arg) do
        KernelShtf.Mil.Server.start_link(__MODULE__, init_arg)
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
