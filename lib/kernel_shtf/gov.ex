defmodule KernelShtf.Gov do
  @moduledoc """
  Provides macros for defining composable state machines with a clean DSL.
  Gov is short for governor and is mechanized similar to a loom.
  """

  require Logger

  defmacro __using__(_opts) do
    quote do
      import KernelShtf.Gov
      require Logger
    end
  end

  # allow finite state machine (FSM) to be defined
  defmacro fabric(name, do: block) do
    quote do
      use GenServer

      def start_link(opts \\ []) do
        name = Keyword.get(opts, :name, __MODULE__)
        GenServer.start_link(__MODULE__, opts, name: name)
      end

      # Add get_state function
      def get_state(pid) do
        {:ok, :sys.get_state(pid)}
      end

      # Default init callback
      @impl true
      def init(args) do
        # allow FSM "canvas" to be defined
        case canvas(args) do
          {:ok, initial_state} -> {:ok, initial_state}
          other -> other
        end
      end

      @impl true
      def handle_call(
            {:state, expected_state, event},
            _from,
            %{current_state: current_state, data: data} = state
          )
          when expected_state == current_state do
        case handle_state_event(event, state) do
          {:weft, new_data, next_state} ->
            {:reply, {:ok, next_state}, %{current_state: next_state, data: new_data}}

          {:warp, new_data} ->
            {:reply, {:ok, current_state}, %{current_state: current_state, data: new_data}}
        end
      end

      @impl true
      def handle_call({:state, expected_state, _event}, _from, state) do
        {:reply, {:error, :invalid_state}, state}
      end

      defoverridable init: 1

      unquote(block)
    end
  end

  # allow FSM "state" to be defined
  defmacro pattern(state_name, do: block) do
    quote do
      defp handle_state_event(event, %{current_state: unquote(state_name)} = state) do
        var!(state) = state
        var!(event) = event
        unquote(block)
      end
    end
  end

  # allow FSM state "transition" to be defined
  defmacro weft(to: next_state, state: state_expr) do
    quote do
      {:weft, unquote(state_expr).data, unquote(next_state)}
    end
  end

  # allow FSM state "stay" to be defined
  defmacro warp(state: state_expr) do
    quote do
      {:warp, unquote(state_expr).data}
    end
  end

  # allow FSM "when_event" to be defined
  defmacro weave(pattern, do: block) do
    quote do
      case var!(event) do
        unquote(pattern) ->
          unquote(block)

        _ ->
          {:warp, var!(state).data}
      end
    end
  end

  # allow FSM state "effects" to be defined
  defmacro texture(name, args, _state_var, do: block) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(block)
      end
    end
  end

  defmacro compose(machines) do
    quote do
      def handle_call({:compose, event}, _from, states) do
        results =
          Enum.map(unquote(machines), fn machine ->
            GenServer.call(machine, {:event, event})
          end)

        case Enum.all?(results, &match?({:ok, _}, &1)) do
          true -> {:reply, :ok, states}
          false -> {:reply, {:error, results}, states}
        end
      end
    end
  end
end
