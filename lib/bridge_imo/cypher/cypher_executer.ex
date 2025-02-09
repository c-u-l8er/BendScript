defmodule CypherExecutor do
  alias Graffiti
  require Logger

  def execute(query, state) do
    Logger.debug("""
    Executing query:
      Query: #{inspect(query)}
      State: #{inspect(state)}
    """)

    {tx_id, state} = Graffiti.begin_transaction(state)
    Logger.debug("Started transaction #{tx_id}")

    try do
      case parse_query(query) do
        {:ok, parsed_query} ->
          Logger.debug("Successfully parsed query: #{inspect(parsed_query)}")

          case execute_parsed_query(parsed_query, state, tx_id) do
            {:ok, result, new_state} ->
              Logger.debug("Query executed successfully, committing transaction")
              {_commit_result, final_state} = Graffiti.commit_transaction(new_state, tx_id)
              {:ok, {result, final_state}}

            {:error, reason} ->
              Logger.error("Query execution failed: #{reason}")
              {_rollback_result, _state} = Graffiti.rollback_transaction(state, tx_id)
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Query parsing failed: #{reason}")
          {_rollback_result, _state} = Graffiti.rollback_transaction(state, tx_id)
          {:error, reason}
      end
    catch
      error ->
        Logger.error("Unexpected error: #{inspect(error)}")
        {_rollback_result, _state} = Graffiti.rollback_transaction(state, tx_id)
        {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  defp parse_query(query) do
    Logger.debug("""
    Parsing query:
      Raw query: #{inspect(query)}
    """)

    parts = String.split(query, " ", trim: true)
    Logger.debug("Query parts: #{inspect(parts)}")

    case parts do
      ["CREATE" | rest] ->
        Logger.debug("Handling CREATE query")
        parse_create_and_return(rest)

      ["MATCH" | rest] ->
        Logger.debug("Handling MATCH query")
        parse_match_and_return(rest)

      _ ->
        Logger.error("Unsupported query format")
        {:error, "Unsupported query format"}
    end
  end

  defp parse_create_and_return(parts) do
    case parts do
      [node_pattern, "RETURN", var] ->
        with {:ok, pattern} <- parse_create_pattern(node_pattern) do
          {:ok, {:create_and_return, pattern, var}}
        end

      _ ->
        {:error, "Invalid CREATE query format"}
    end
  end

  defp parse_match_and_return(parts) do
    case parts do
      [node_pattern, "RETURN", var] ->
        with {:ok, pattern} <- parse_pattern(node_pattern) do
          {:ok, {:match_and_return, pattern, var}}
        end

      _ ->
        {:error, "Invalid MATCH query format"}
    end
  end

  defp execute_parsed_query(
         {:create_and_return, {:node, label, _var, properties}, _return_var},
         state,
         tx_id
       ) do
    vertex_id = UUID.uuid4()
    Logger.debug("Creating vertex with ID: #{vertex_id}")

    case Graffiti.add_vertex(state, tx_id, String.to_atom(label), vertex_id, properties) do
      {:ok, new_state} ->
        {:ok, [{vertex_id, nil, nil}], new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_parsed_query({:match_and_return, {:node, label, _var}}, state, _tx_id) do
    {results, new_state} = Graffiti.query(state, [String.to_atom(label)])
    {:ok, results, new_state}
  end

  defp parse_create_pattern(pattern) do
    # Extract node pattern like "(n:Label {prop: 'value'})"
    case Regex.run(~r/\((\w+):(\w+)\s*({[^}]*})?\)/, pattern) do
      [_, var, label, props_str] when not is_nil(props_str) ->
        with {:ok, properties} <- parse_properties(props_str) do
          {:ok, {:node, label, var, properties}}
        end

      [_, var, label, nil] ->
        {:ok, {:node, label, var, %{}}}

      _ ->
        {:error, "Invalid CREATE pattern"}
    end
  end

  defp parse_pattern(pattern) do
    # Extract node pattern like "(n:Label)"
    case Regex.run(~r/\((\w+):(\w+)\)/, pattern) do
      [_, var, label] -> {:ok, {:node, label, var}}
      _ -> {:error, "Invalid pattern format"}
    end
  end

  defp parse_properties(props_str) do
    # Remove curly braces and split by comma
    props_str
    |> String.trim("{}")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reduce({:ok, %{}}, fn
      "", acc -> acc
      prop, {:ok, acc} -> parse_property(prop, acc)
    end)
  end

  defp parse_property(prop_str, acc) do
    case String.split(prop_str, ":", parts: 2) do
      [key, value] ->
        key = key |> String.trim() |> String.to_atom()
        value = value |> String.trim() |> parse_value()
        {:ok, Map.put(acc, key, value)}

      _ ->
        {:error, "Invalid property format"}
    end
  end

  defp parse_value(value_str) do
    value_str = String.trim(value_str)

    cond do
      String.starts_with?(value_str, "'") ->
        String.replace(value_str, ~r/^'|'$/, "")

      Regex.match?(~r/^\d+$/, value_str) ->
        String.to_integer(value_str)

      Regex.match?(~r/^\d+\.\d+$/, value_str) ->
        String.to_float(value_str)

      value_str == "true" ->
        true

      value_str == "false" ->
        false

      true ->
        value_str
    end
  end
end
