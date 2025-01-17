defmodule KernelShtf.Wonder.Macros do
  @moduledoc """
  Provides macros for defining server force calls and spell casts.
  """

  defmacro force(name, args, do: body) do
    quote do
      def unquote(name)(server, unquote_splicing(args)) do
        KernelShtf.Wonder.Server.call(
          server,
          {__MODULE__, unquote(name), [unquote_splicing(args)]}
        )
      end

      def handle_call({__MODULE__, unquote(name), [unquote_splicing(args)]}, _from, state) do
        var!(state) = state
        result = unquote(body)

        {reply, new_state} =
          case result do
            %{} = new_state ->
              state_keys = Map.keys(state)

              if map_size(new_state) == map_size(state) and
                   Enum.all?(state_keys, &Map.has_key?(new_state, &1)) do
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

  defmacro spell(name, args, do: body) do
    quote do
      def unquote(name)(server, unquote_splicing(args)) do
        KernelShtf.Wonder.Server.cast(
          server,
          {__MODULE__, unquote(name), [unquote_splicing(args)]}
        )
      end

      def handle_cast({__MODULE__, unquote(name), [unquote_splicing(args)]}, state) do
        var!(state) = state
        new_state = unquote(body)
        {:noreply, new_state}
      end
    end
  end

  defmacro magic(do: block) do
    quote do
      def init(_args) do
        {:ok, unquote(block)}
      end
    end
  end
end
