defmodule ExCypher do
  require Logger

  defmacro cypher(do: block) do
    clauses =
      case block do
        {:__block__, [], exprs} -> exprs
        expr -> [expr]
      end

    quote do
      clauses =
        unquote(clauses)
        |> Enum.map(fn clause -> clause end)
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(&(&1 == ""))

      query = Enum.join(clauses, " ")
      Logger.debug("Generated query string: #{inspect(query)}")
      query
    end
  end

  def match(pattern) do
    Logger.debug("Building MATCH clause with pattern: #{inspect(pattern)}")
    "MATCH " <> pattern
  end

  def where(condition) do
    Logger.debug("Building WHERE clause with condition: #{inspect(condition)}")
    "WHERE " <> condition
  end

  def create(pattern) do
    Logger.debug("Building CREATE clause with pattern: #{inspect(pattern)}")
    "CREATE " <> pattern
  end

  def return(var) when is_atom(var) do
    Logger.debug("Building RETURN clause for variable: #{inspect(var)}")
    "RETURN " <> Atom.to_string(var)
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
end
