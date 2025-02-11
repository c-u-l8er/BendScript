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

    # Using Regex.scan to find CREATE or MATCH clauses and their arguments
    # Attempt to match the full pattern with properties
    case Regex.scan(~r/(CREATE|MATCH)\s+(\(([^)]+)\))\s+RETURN\s+(\w+)/, query) do
      [[_full_match, command, node_pattern, _node_contents, return_var]] ->
        Logger.debug("Full Match with properties")
        handle_command(command, node_pattern, return_var)

      _ ->
        # If the full pattern fails, try the simpler pattern without properties
        case Regex.scan(~r/(CREATE|MATCH)\s+(\(([^)]+)\))\s+RETURN\s+(\w+)/, query) do
          [[_full_match, command, node_pattern, return_var]] ->
            Logger.debug("Full Match without properties")
            handle_command(command, node_pattern, return_var)

          _ ->
            Logger.error("Unsupported query format")
            {:error, "Unsupported query format"}
        end
    end
  end

  defp handle_command(command, node_pattern, return_var) do
    case String.upcase(command) do
      "CREATE" ->
        Logger.debug("Handling CREATE query")

        with {:ok, {var, label, properties}} <- parse_node(String.trim(node_pattern)) do
          {:ok, {:create_and_return, {:node, label, var, properties}, return_var}}
        end

      "MATCH" ->
        Logger.debug("Handling MATCH query")

        with {:ok, {var, label, properties}} <- parse_node_simple(String.trim(node_pattern)) do
          {:ok, {:match_and_return, {:node, label, var, properties}, return_var}}
        end

      _ ->
        {:error, "Unsupported command"}
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
        with {:ok, {var, label, properties}} <- parse_node(node_pattern) do
          {:ok, {:create_and_return, {:node, label, var, properties}, var}}
        end

      _ ->
        {:error, "Invalid CREATE query format"}
    end
  end

  defp parse_match_and_return(parts) do
    case parts do
      [node_pattern, "RETURN", var] ->
        with {:ok, {var, label, properties}} <- parse_node(node_pattern) do
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

  defp execute_parsed_query({:match_and_return, {:node, label, _var, properties}}, state, _tx_id) do
    label_atom = String.to_atom(label)
    Logger.debug("Executing MATCH query for label: #{label}, properties: #{inspect(properties)}")
    # Modify the query function to support filtering by properties
    query_pattern =
      if map_size(properties) > 0 do
        [properties]
      else
        [label_atom]
      end

    {results, new_state} = Graffiti.query(state, query_pattern)
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

      Regex.match?(~r/^\d+$/, value_str) ->
        String.to_integer(value_str)

      Regex.match?(~r/^\d+\.\d+$/, value_str) ->
        String.to_float(value_str)

      value_str == "true" ->
        true

      value_str == "false" ->
        false

      true ->
        value_str |> String.trim()
    end
  end

  defp parse_node(node_string) do
    Logger.debug("Parsing node string: #{inspect(node_string)}")
    # Regex to capture label and properties within the node string
    case Regex.run(~r/(\w+):(\w+)(?:\s*{([^}]*)})?/, node_string) do
      [_, var, label, properties_content] ->
        Logger.debug(
          "Found var: #{var}, label: #{label}, properties_string: #{properties_content}"
        )

        # If properties exist, parse them; otherwise, return an empty map
        properties =
          if properties_content do
            case parse_properties(properties_content) do
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

  defp parse_properties(props_str) do
    Logger.debug("Parsing properties string: #{inspect(props_str)}")
    # Remove curly braces and split by comma
    props_str = String.trim(props_str, "{}")
    props = String.split(props_str, ",")
    Logger.debug("Split properties: #{inspect(props)}")

    Enum.reduce(props, {:ok, %{}}, fn prop, acc ->
      case acc do
        {:ok, current_props} ->
          prop = String.trim(prop)

          case String.split(prop, ":", parts: 2) do
            [key, value] ->
              key = String.trim(key) |> String.to_atom()
              value = String.replace(value, ~r/^'|'$/, "") |> String.trim()
              Logger.debug("Parsed property: key=#{key}, value=#{value}")
              {:ok, Map.put(current_props, key, value)}

            _ ->
              {:error, "Invalid property format"}
          end

        {:error, _} ->
          # Pass the error through
          acc
      end
    end)
  end
end
