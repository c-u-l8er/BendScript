defmodule ExCypher do
  require Logger

  defmacro cypher(do: block) do
    quote do
      Logger.debug("Building Cypher query from block: #{inspect(unquote(block))}")
      ExCypher.Builder.build(unquote(block))
    end
  end

  def match(pattern) do
    Logger.debug("Building MATCH clause with pattern: #{inspect(pattern)}")
    ["MATCH", pattern]
  end

  def where(condition) do
    Logger.debug("Building WHERE clause with condition: #{inspect(condition)}")
    ["WHERE", condition]
  end

  def create(pattern) do
    Logger.debug("Building CREATE clause with pattern: #{inspect(pattern)}")
    ["CREATE", pattern]
  end

  def return(var) when is_atom(var) do
    Logger.debug("Building RETURN clause for variable: #{inspect(var)}")
    ["RETURN", "#{var}"]
  end

  def node(var, labels, properties \\ nil) do
    Logger.debug("""
    Building node pattern:
      var: #{inspect(var)}
      labels: #{inspect(labels)}
      properties: #{inspect(properties)}
    """)

    var_str = to_string(var)
    label_str = labels |> Enum.map(&":#{&1}") |> Enum.join("")
    props_str = if properties, do: " #{build_properties(properties)}", else: ""
    result = "(#{var_str}#{label_str}#{props_str})"
    Logger.debug("Built node pattern: #{result}")
    result
  end

  defp build_properties(props) when is_map(props) do
    Logger.debug("Building properties string from: #{inspect(props)}")

    props_str =
      props
      |> Enum.map(fn {k, v} -> "#{k}: #{format_value(v)}" end)
      |> Enum.join(", ")

    result = "{#{props_str}}"
    Logger.debug("Built properties string: #{result}")
    result
  end

  defp format_value(value) when is_binary(value), do: "'#{value}'"
  defp format_value(value), do: to_string(value)

  defmodule Builder do
    require Logger

    def build(ast) do
      Logger.debug("Building query from AST: #{inspect(ast)}")
      {clauses, state} = traverse(ast, %{params: [], returns: []})
      Logger.debug("Traversal result - clauses: #{inspect(clauses)}, state: #{inspect(state)}")

      result =
        clauses
        |> List.flatten()
        |> tap(&Logger.debug("After flatten: #{inspect(&1)}"))
        |> Enum.reject(&is_nil/1)
        |> tap(&Logger.debug("After nil rejection: #{inspect(&1)}"))
        |> Enum.reject(&(&1 == ""))
        |> tap(&Logger.debug("After empty string rejection: #{inspect(&1)}"))
        |> Enum.join(" ")

      Logger.debug("Final built query: #{result}")
      result
    end

    defp traverse({:__block__, _, statements}, state) do
      Logger.debug("Traversing block with statements: #{inspect(statements)}")

      {clauses, final_state} =
        Enum.reduce(statements, {[], state}, fn stmt, {acc_clauses, acc_state} ->
          Logger.debug("Processing statement: #{inspect(stmt)}")
          {clause, new_state} = traverse(stmt, acc_state)

          Logger.debug(
            "Statement result - clause: #{inspect(clause)}, state: #{inspect(new_state)}"
          )

          {acc_clauses ++ [clause], new_state}
        end)

      Logger.debug(
        "Block traversal complete - clauses: #{inspect(clauses)}, state: #{inspect(final_state)}"
      )

      {clauses, final_state}
    end

    defp traverse({func, _, [arg]} = expr, state)
         when func in [:match, :where, :create, :return] do
      Logger.debug("Traversing function call: #{inspect(expr)}")
      result = apply(ExCypher, func, [arg])
      Logger.debug("Function call result: #{inspect(result)}")
      {result, state}
    end

    defp traverse(value, state) when is_binary(value) or is_list(value) do
      Logger.debug("Traversing direct value: #{inspect(value)}")
      {value, state}
    end

    defp traverse(other, state) do
      Logger.debug("Traversing other value: #{inspect(other)}")
      result = to_string(other)
      Logger.debug("Converted to string: #{inspect(result)}")
      {result, state}
    end
  end
end
