defmodule ExCypher do
  defmacro cypher(do: block) do
    quote do
      ExCypher.Builder.build(unquote(block))
    end
  end

  def match(pattern), do: "MATCH #{pattern}"
  def where(condition), do: "WHERE #{condition}"
  def create(pattern), do: "CREATE #{pattern}"
  def return(var), do: "RETURN #{var}"

  def node(var, labels, properties \\ nil) do
    label_str = labels |> Enum.map(&":#{&1}") |> Enum.join("")
    props_str = if properties, do: " #{build_properties(properties)}", else: ""
    "(#{var}#{label_str}#{props_str})"
  end

  defp build_properties(props) when is_map(props) do
    props_str =
      props
      |> Enum.map(fn {k, v} -> "#{k}: #{format_value(v)}" end)
      |> Enum.join(", ")

    "{#{props_str}}"
  end

  defp format_value(value) when is_binary(value), do: "'#{value}'"
  defp format_value(value), do: to_string(value)

  defmodule Builder do
    def build(ast) do
      {query, _state} = traverse(ast, %{params: [], returns: []})
      query
    end

    defp traverse({:match, _, [args]}, state) do
      {pattern, state} = build_pattern(args, state)
      {"MATCH #{pattern}", state}
    end

    defp traverse({:where, _, [condition]}, state) when is_binary(condition) do
      {"WHERE #{condition}", state}
    end

    defp traverse({:create, _, [args]}, state) do
      {pattern, state} = build_pattern(args, state)
      {"CREATE #{pattern}", state}
    end

    defp traverse({:return, _, [what]}, state) do
      {return_clause, state} = build_return(what, state)
      {"RETURN #{return_clause}", state}
    end

    defp traverse({:__block__, _, statements}, state) do
      {clauses, final_state} =
        Enum.reduce(statements, {[], state}, fn stmt, {clauses, acc_state} ->
          {clause, new_state} = traverse(stmt, acc_state)
          {[clause | clauses], new_state}
        end)

      {Enum.reverse(clauses) |> Enum.join(" "), final_state}
    end

    defp traverse(statement, state) do
      {to_string(statement), state}
    end

    defp build_pattern({:node, _, [var, labels, properties]}, state) when is_atom(var) do
      label_str =
        case labels do
          [single] when is_atom(single) -> ":#{single}"
          list when is_list(list) -> list |> Enum.map(&":#{&1}") |> Enum.join("")
        end

      props_str =
        case properties do
          nil -> ""
          props when is_map(props) -> " " <> build_properties(props)
        end

      {"(#{var}#{label_str}#{props_str})", state}
    end

    defp build_pattern({:node, _, [var, labels]}, state) when is_atom(var) do
      build_pattern({:node, nil, [var, labels, nil]}, state)
    end

    defp build_properties(props) do
      props_str =
        props
        |> Enum.map(fn {k, v} -> "#{k}: #{format_value(v)}" end)
        |> Enum.join(", ")

      "{#{props_str}}"
    end

    defp format_value(value) when is_binary(value), do: "'#{value}'"
    defp format_value(value), do: to_string(value)

    defp build_return(what, state) when is_atom(what) do
      {"#{what}", state}
    end
  end
end
