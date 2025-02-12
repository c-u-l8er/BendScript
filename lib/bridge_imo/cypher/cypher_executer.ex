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

    # Updated regex to capture entire node pattern and WHERE clause
    case Regex.scan(
           # WARNING: DO NOT MODIFY THE FOLLOWING REGEX UNLESS YOU ARE USING DEEP REASON/THINK LOL
           ~r/(CREATE|MATCH)\s+\(([^)]+)\)\s*(WHERE\s+(.*?))?\s*RETURN\s+(\w+)/i,
           query
         ) do
      [[_full_match, command, node_pattern, _where_keyword, where_clause, return_var]] ->
        Logger.debug("Matched CREATE or MATCH with node pattern and RETURN")
        handle_command(command, node_pattern, where_clause, return_var)

      _ ->
        Logger.error("Unsupported query format")
        {:error, "Unsupported query format"}
    end
  end

  defp handle_command(command, node_pattern, where_clause, return_var) do
    # Parse node_pattern into var, label, properties_str using a secondary regex
    case Regex.run(~r/^\s*(\w+):(\w+)(?:\s*\{([^}]*)\})?/, node_pattern) do
      [_, var, label, properties_str] ->
        Logger.debug("Handling #{command} query for #{var}:#{label}")
        properties_str = if properties_str == "", do: nil, else: properties_str
        handle_parsed_command(command, var, label, properties_str, where_clause, return_var)

      [_, var, label] ->
        Logger.debug("Handling #{command} query for #{var}:#{label} without properties")
        handle_parsed_command(command, var, label, nil, where_clause, return_var)

      _ ->
        {:error, "Invalid node pattern: #{node_pattern}"}
    end
  end

  defp handle_parsed_command("CREATE", var, label, properties_str, where_clause, return_var) do
    Logger.debug("Handling CREATE query")

    with {:ok, properties} <- parse_properties(properties_str) do
      {:ok, {:create_and_return, {:node, label, var, properties}, return_var}}
    end
  end

  defp handle_parsed_command("MATCH", var, label, properties_str, where_clause, return_var) do
    Logger.debug("Handling MATCH query")

    with {:ok, properties} <- parse_properties(properties_str) do
      {:ok, {:match_and_return, {:node, label, var, properties}, return_var, where_clause}}
    end
  end

  defp parse_node_simple(node_string) do
    Logger.debug("Parsing simple node string: #{inspect(node_string)}")
    # Regex to capture label and properties within the node string
    case Regex.run(~r/(\w+):(\w+)/, node_string) do
      [_, var, label] ->
        Logger.debug("Found var: #{var}, label: #{label}")

        {:ok, {var, label, %{}}}

      _ ->
        Logger.error("Invalid node format")
        {:error, "Invalid node format"}
    end
  end

  defp parse_create_and_return(parts) do
    case parts do
      [node_pattern, "RETURN", var] ->
        with {:ok, {var, label, properties}} <- parse_node(node_pattern, nil) do
          {:ok, {:create_and_return, {:node, label, var, properties}, var}}
        end

      _ ->
        {:error, "Invalid CREATE query format"}
    end
  end

  defp parse_match_and_return(parts) do
    case parts do
      [node_pattern, "RETURN", var] ->
        with {:ok, {var, label, properties}} <- parse_node(node_pattern, nil) do
          {:ok, {:match_and_return, {:node, label, var, properties}, var}}
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
    label_atom = String.to_atom(label)

    case Graffiti.add_vertex(state, tx_id, label_atom, vertex_id, properties) do
      {:ok, new_state} ->
        {:ok, [{vertex_id, nil, nil}], new_state}

      {:error, reason} ->
        Logger.error("Error creating vertex: #{reason}")
        {:error, reason}
    end
  end

  defp execute_parsed_query(
         {:match_and_return, {:node, label, _var, properties}, _return_var, where_clause},
         state,
         _tx_id
       ) do
    label_atom = String.to_atom(label)
    Logger.debug("Executing MATCH query for label: #{label}, properties: #{inspect(properties)}")

    # Get all vertex IDs of the given type
    vertex_ids =
      state.graph.vertex_map
      |> Map.to_list()
      |> Enum.filter(fn {_, vertex} ->
        vertex.properties[:type] == label_atom
      end)
      |> Enum.map(fn {id, _} -> id end)

    # Apply the WHERE clause if it exists
    filtered_vertex_ids =
      if where_clause do
        Logger.debug("Applying WHERE clause: #{where_clause}")
        apply_where_clause(vertex_ids, state, where_clause)
      else
        Logger.debug("No WHERE clause to apply")
        vertex_ids
      end

    # Convert to the format expected by the test
    results = Enum.map(filtered_vertex_ids, fn id -> {id, nil, nil} end)
    Logger.debug("Executing MATCH query results: #{inspect(results)}")

    {:ok, results, state}
  end

  defp apply_where_clause(vertex_ids, state, where_clause) do
    # Basic parsing of the where clause (e.g., "s.name = 'Enterprise'")
    case Regex.run(~r/(\w+)\.(\w+)\s*==\s*['"]?([^'"]*)['"]?/, where_clause) do
      [_, var, property, value] ->
        Logger.debug(
          "Extracted var: #{var}, property: #{property}, value: #{value} from WHERE clause"
        )

        Enum.filter(vertex_ids, fn vertex_id ->
          vertex = Map.get(state.graph.vertex_map, vertex_id)

          case Map.get(vertex.properties, String.to_atom(property)) do
            nil ->
              Logger.debug("Property #{property} is nil for vertex #{vertex_id}")
              # Property is missing
              false

            prop_value ->
              Logger.debug(
                "Comparing property #{property} with value #{value} for vertex #{vertex_id}"
              )

              # Compare
              prop_value == value
          end
        end)

      _ ->
        Logger.warn("Could not parse WHERE clause: #{where_clause}")
        # Or handle the error differently
        []
    end
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
    Logger.debug("Parsing value string: #{inspect(value_str)}")

    cond do
      String.starts_with?(value_str, "'") ->
        String.replace(value_str, ~r/^'|'$/, "") |> String.trim()

      String.match?(value_str, ~r/^\d+$/) ->
        String.to_integer(value_str)

      String.match?(value_str, ~r/^\d+\.\d+$/) ->
        String.to_float(value_str)

      value_str == "true" ->
        true

      value_str == "false" ->
        false

      true ->
        value_str |> String.trim()
    end
  end

  defp parse_node(node_string, properties_str) do
    Logger.debug("Parsing node string: #{inspect(node_string)}")
    # Regex to capture label and properties within the node string
    case Regex.run(~r/(\w+):(\w+)/, node_string) do
      [_, var, label] ->
        Logger.debug("Found var: #{var}, label: #{label}")

        properties =
          if properties_str do
            case parse_properties(properties_str) do
              {:ok, props} ->
                Logger.debug("Successfully parsed properties: #{inspect(props)}")
                props

              {:error, reason} ->
                Logger.error("Error parsing properties: #{reason}")
                {:error, reason}
            end
          else
            Logger.debug("No properties found, using an empty map")
            %{}
          end

        {:ok, {var, label, properties}}

      _ ->
        Logger.error("Invalid node format")
        {:error, "Invalid node format"}
    end
  end

  defp parse_node_match(node_string) do
    Logger.debug("Parsing node string for match: #{inspect(node_string)}")

    # Regex to capture label and properties within the node string
    case Regex.run(~r/(\w+):(\w+)/, node_string) do
      [_, var, label] ->
        Logger.debug("Found var: #{var}, label: #{label}")

        {:ok, {var, label}}

      _ ->
        Logger.error("Invalid node format")
        {:error, "Invalid node format"}
    end
  end

  defp parse_properties(nil), do: {:ok, %{}}

  defp parse_properties(properties_str) do
    Logger.debug("Parsing properties string: #{inspect(properties_str)}")
    props = String.split(properties_str, ~r/\s*,\s*/)

    Enum.reduce(props, {:ok, %{}}, fn prop, acc ->
      case acc do
        {:ok, current_props} ->
          case String.split(prop, ~r/\s*:\s*/, parts: 2) do
            [key, value] ->
              key = String.trim(key) |> String.to_atom()
              value = parse_value(String.trim(value))
              Logger.debug("Parsed property: key=#{key}, value=#{inspect(value)}")
              {:ok, Map.put(current_props, key, value)}

            _ ->
              {:error, "Invalid property format: #{prop}"}
          end

        {:error, _} ->
          acc
      end
    end)
  end
end
