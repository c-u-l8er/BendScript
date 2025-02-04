defmodule KernelShtf.Mil.Macros do
  @moduledoc """
  Provides macros for defining server force calls and spell casts.
  """

  defmacro force(name, args, do: body) do
    quote do
      def unquote(name)(server, unquote_splicing(args)) do
        KernelShtf.Mil.Server.call(
          server,
          {__MODULE__, unquote(name), [unquote_splicing(args)]}
        )
      end

      def handle_call({__MODULE__, unquote(name), [unquote_splicing(args)]}, _from, floppy) do
        var!(floppy) = floppy
        result = unquote(body)

        {reply, new_floppy} =
          case result do
            %{} = new_floppy ->
              floppy_keys = Map.keys(floppy)

              if map_size(new_floppy) == map_size(floppy) and
                   Enum.all?(floppy_keys, &Map.has_key?(new_floppy, &1)) do
                {Map.get(new_floppy, hd(floppy_keys)), new_floppy}
              else
                {result, floppy}
              end

            other ->
              {other, floppy}
          end

        {:reply, reply, new_floppy}
      end
    end
  end

  defmacro spell(name, args, do: body) do
    quote do
      def unquote(name)(server, unquote_splicing(args)) do
        KernelShtf.Mil.Server.cast(
          server,
          {__MODULE__, unquote(name), [unquote_splicing(args)]}
        )
      end

      def handle_cast({__MODULE__, unquote(name), [unquote_splicing(args)]}, floppy) do
        var!(floppy) = floppy
        new_floppy = unquote(body)
        {:noreply, new_floppy}
      end
    end
  end

  defmacro magnetic(do: block) do
    quote do
      def init(_args) do
        {:ok, unquote(block)}
      end
    end
  end
end
