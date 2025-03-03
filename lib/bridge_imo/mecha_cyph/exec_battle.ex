defmodule BridgeImo.MechaCyph.ExecBattle do
  require Logger
  import KernelShtf.BenBen

  defmacro cyph(opts, do: block) do
    quote do
      mecha_pid = Keyword.get(unquote(opts), :mecha, :undefined)

      result =
        try do
          unquote(block)
        rescue
          e ->
            Logger.error("An error occurred in the cypher block: #{inspect(e)}")
            {:error, e}
        end

      {:ok, drum} = MechaCyph.get_drum(mecha_pid)
      query_map = %{memory: drum.memory, rotate: drum.rotate}
      Logger.info("Returning query with: #{inspect(result)}")
      query_map
    end
  end

  defmacro match(node_details) do
    quote do
      {:match, unquote(node_details)}
    end
  end

  defmacro create(node_details) do
    quote do
      {:create, unquote(node_details)}
    end
  end

  defmacro where(expression) do
    quote do
      {:where, unquote(expression)}
    end
  end

  defmacro return(expression) do
    quote do
      :return
    end
  end

  defmacro node(identifier, labels, properties \\ %{}) do
    quote do
      %{
        id: unquote(identifier),
        labels: unquote(Macro.escape(labels)),
        properties: unquote(Macro.escape(properties))
      }
    end
  end
end
