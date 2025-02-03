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
            %{current_state: current_state} = state
          ) do
        Logger.debug(
          "Handling event: #{inspect(event)}. Current state: #{current_state}, Expected state: #{expected_state}"
        )

        if expected_state == current_state do
          case handle_state_event(event, state) do
            {:weft, new_data, next_state} ->
              Logger.debug("Transitioning to #{next_state}")
              {:reply, {:ok, next_state}, %{current_state: next_state, data: new_data}}

            {:warp, new_state} ->
              Logger.debug("Staying in #{current_state}")
              Logger.info("new_state!!! -> #{inspect(new_state)}")
              {:reply, {:ok, current_state}, new_state}

            other ->
              Logger.error("Unexpected handle_state_event result: #{inspect(other)}")
              {:reply, {:error, :invalid_transition}, state}
          end
        else
          Logger.error(
            "Invalid state transition. Expected #{expected_state}, got #{current_state}"
          )

          {:reply, {:error, :invalid_state}, state}
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
      defp handle_state_event(event_data, current_state_data) do
        var!(state) = current_state_data
        var!(event) = event_data

        result = unquote(block)
        Logger.info("Pattern result: #{inspect(result)}")
        result
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
      state_to_return = unquote(state_expr)
      Logger.info("WARP - Returning state: #{inspect(state_to_return)}")
      {:warp, state_to_return}
    end
  end

  # allow FSM "when_event" to be defined
  defmacro weave(pattern, do: block) do
    quote do
      case var!(event) do
        unquote(pattern) ->
          unquote(block)

        _ ->
          {:warp, %{current_state: var!(state).current_state, data: var!(state).data}}
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
