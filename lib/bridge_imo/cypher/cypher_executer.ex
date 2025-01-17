defmodule CypherExecutor do
  def execute(query, node_name) do
    # Start a transaction
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node_name)

    try do
      # Parse and execute the query
      result = execute_query(query, node_name, tx_id)

      # Commit the transaction
      {:ok, _} = DistGraphDatabase.commit_transaction(node_name, tx_id)

      {:ok, result}
    catch
      error ->
        # Rollback on error
        DistGraphDatabase.rollback_transaction(node_name, tx_id)
        {:error, error}
    end
  end

  defp execute_query(query, node_name, tx_id) do
    case parse_query(query) do
      {:match_where, pattern, condition, return} ->
        execute_match_where(pattern, condition, return, node_name, tx_id)

      {:match, pattern, return} ->
        execute_match(pattern, return, node_name, tx_id)

      {:create, pattern} ->
        execute_create(pattern, node_name, tx_id)

      other ->
        raise "Unsupported query type: #{inspect(other)}"
    end
  end

  defp parse_query(query) do
    # Simple parser for demonstration
    cond do
      String.starts_with?(query, "MATCH") ->
        parts =
          query
          |> String.replace(~r/[\(\)]/, " ")
          |> String.split()

        case parts do
          [_, pattern, "WHERE", condition, "RETURN", return] ->
            {:match_where, pattern, condition, return}

          [_, pattern, "RETURN", return] ->
            {:match, pattern, return}
        end

      String.starts_with?(query, "CREATE") ->
        [_, pattern] =
          query
          |> String.replace(~r/[\(\)]/, " ")
          |> String.split(" ", parts: 2)

        {:create, String.trim(pattern)}

      true ->
        {:error, "Unsupported query format"}
    end
  end

  defp execute_match_where(pattern, condition, return, node_name, tx_id) do
    {:node, label, var} = parse_pattern(pattern)
    condition = parse_condition(condition)

    # Query vertices with matching label and filter by condition
    vertices = query_vertices(node_name, tx_id, label)
    Enum.filter(vertices, &matches_condition?(&1, condition))
  end

  defp parse_condition(condition) do
    # Simple condition parser for "property = value"
    [var_prop, value] = String.split(condition, "=")
    [_var, prop] = String.split(String.trim(var_prop), ".")
    value = String.trim(value)
    {String.to_atom(prop), String.replace(value, ~r/^'|'$/, "")}
  end

  defp matches_condition?(vertex, {property, value}) do
    vertex.properties[property] == value
  end

  defp execute_match(pattern, return, node_name, tx_id) do
    # Convert pattern to graph traversal
    case parse_pattern(pattern) do
      {:node, label, var} ->
        # Query vertices with matching label
        query_vertices(node_name, tx_id, label)
    end
  end

  defp execute_create(pattern, node_name, tx_id) do
    case parse_create_pattern(pattern) do
      {:node, label, var, properties} ->
        # Generate unique ID for new vertex
        vertex_id = UUID.uuid4()

        # Create vertex in the graph
        {:ok, _} =
          DistGraphDatabase.add_vertex(
            node_name,
            tx_id,
            String.to_atom(label),
            vertex_id,
            properties
          )

        {:ok, vertex_id}

      {:relationship, from_pattern, type, to_pattern} ->
        # Create vertices and relationship
        {:ok, from_id} = execute_create(from_pattern, node_name, tx_id)
        {:ok, to_id} = execute_create(to_pattern, node_name, tx_id)

        # Create edge between vertices
        {:ok, _} =
          DistGraphDatabase.add_edge(
            node_name,
            tx_id,
            from_id,
            to_id,
            String.to_atom(type),
            %{}
          )

        {:ok, {from_id, to_id}}
    end
  end

  defp parse_create_pattern(pattern) do
    cond do
      # Match node pattern like "n:Label {prop: 'value'}"
      String.contains?(pattern, "{") ->
        [node_part, props_part] = String.split(pattern, "{", parts: 2)
        [var, label] = String.split(String.trim(node_part), ":")

        properties =
          props_part
          |> String.replace("}", "")
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_property/1)
          |> Map.new()

        {:node, label, var, properties}

      # Match simple node pattern like "n:Label"
      String.contains?(pattern, ":") ->
        [var, label] = String.split(pattern, ":")
        {:node, label, var, %{}}

      # Match relationship pattern like "(a:Label)-[r:TYPE]->(b:Label)"
      String.contains?(pattern, "->") ->
        [from_part, rel_part, to_part] = String.split(pattern, ~r/-\[:(\w+)\]->/)
        {:relationship, from_part, rel_part, to_part}
    end
  end

  defp parse_property(prop_str) do
    [key, value] = String.split(prop_str, ":", parts: 2)
    {String.to_atom(String.trim(key)), parse_value(String.trim(value))}
  end

  defp parse_value(value_str) do
    cond do
      String.starts_with?(value_str, "'") ->
        String.replace(value_str, ~r/^'|'$/, "")

      String.match?(value_str, ~r/^\d+$/) ->
        String.to_integer(value_str)

      String.match?(value_str, ~r/^\d+\.\d+$/) ->
        String.to_float(value_str)

      value_str == "true" ->
        true

      value_str == "false" ->
        false

      true ->
        value_str
    end
  end

  defp parse_pattern(pattern) do
    # Extract node pattern like "n:Label"
    [var, label] = String.split(pattern, ":")
    {:node, label, var}
  end

  defp query_vertices(node_name, tx_id, label) do
    # Convert to DistGraphDatabase vertex query
    DistGraphDatabase.query_vertices(node_name, tx_id, label)
  end
end
