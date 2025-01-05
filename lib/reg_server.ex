defmodule RegServer do
  @moduledoc """
  A simplified implementation of GenServer behavior using macros.
  Provides a more regular interface while maintaining core GenServer functionality.
  """

  @doc """
  Defines the behavior for modules using RegServer
  """
  @callback init(term) :: {:ok, term} | {:error, term}
  @callback handle_call(term, {pid, term}, term) :: {:reply, term, term}
  @callback handle_cast(term, term) :: {:noreply, term}
  @callback handle_info(term, term) :: {:noreply, term}

  defmacro __using__(_opts) do
    quote do
      @behaviour RegServer
      import RegServer.Macros

      def start_link(init_arg) do
        RegServer.Server.start_link(__MODULE__, init_arg)
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

  defmodule Macros do
    @moduledoc """
    Provides macros for defining server calls and casts with a more regular interface.
    """

    defmacro defcall(name, args, do: body) do
      quote do
        def unquote(name)(server, unquote_splicing(args)) do
          RegServer.Server.call(server, {__MODULE__, unquote(name), [unquote_splicing(args)]})
        end

        def handle_call({__MODULE__, unquote(name), [unquote_splicing(args)]}, _from, state) do
          var!(state) = state
          result = unquote(body)

          {reply, new_state} = case result do
            %{} = new_state ->
              # Check if maps have same keys
              state_keys = Map.keys(state)
              if map_size(new_state) == map_size(state) and
                 Enum.all?(state_keys, &Map.has_key?(new_state, &1)) do
                # Use first changed value as reply
                {Map.get(new_state, hd(state_keys)), new_state}
              else
                {result, state}
              end
            other ->
              {other, state}
          end

          {:reply, reply, new_state}
        end
      end
    end

    defmacro defcast(name, args, do: body) do
      quote do
        def unquote(name)(server, unquote_splicing(args)) do
          RegServer.Server.cast(server, {__MODULE__, unquote(name), [unquote_splicing(args)]})
        end

        def handle_cast({__MODULE__, unquote(name), [unquote_splicing(args)]}, state) do
          var!(state) = state
          new_state = unquote(body)
          {:noreply, new_state}
        end
      end
    end

    defmacro defstate(do: block) do
      quote do
        def init(_args) do
          {:ok, unquote(block)}
        end
      end
    end
  end

  defmodule Server do
    @moduledoc """
    The core server implementation that handles the process lifecycle and message passing.
    """

    def start_link(module, init_arg) do
      pid = spawn_link(__MODULE__, :init, [module, init_arg])
      {:ok, pid}
    end

    def call(server, request) do
      ref = make_ref()
      send(server, {:call, {self(), ref}, ref, request})
      receive do
        {:reply, ^ref, reply} -> reply
      after
        5000 -> {:error, :timeout}
      end
    end

    def cast(server, request) do
      send(server, {:cast, request})
      :ok
    end

    def init(module, init_arg) do
      case module.init(init_arg) do
        {:ok, state} -> loop(module, state)
        {:error, reason} -> exit(reason)
      end
    end

    defp loop(module, state) do
      receive do
        {:call, from = {pid, _ref}, ref, request} ->
          case module.handle_call(request, from, state) do
            {:reply, reply, new_state} ->
              send(pid, {:reply, ref, reply})
              loop(module, new_state)
          end

        {:cast, request} ->
          case module.handle_cast(request, state) do
            {:noreply, new_state} -> loop(module, new_state)
          end

        msg ->
          case module.handle_info(msg, state) do
            {:noreply, new_state} -> loop(module, new_state)
          end
      end
    end
  end
end
