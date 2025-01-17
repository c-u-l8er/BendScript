defmodule Graffiti do
  require Logger
  import KernelShtf.BenBen
  alias PropGraph
  alias Graffiti.Persistence

  phrenia Transaction do
    # Transaction states
    pending(operations, timestamp)
    committed(changes, timestamp)
    rolled_back(reason, timestamp)
  end

  defmodule Error do
    defexception [:message]
  end

  defmodule State do
    defstruct graph: PropGraph.new(),
              transactions: %{},
              locks: %{},
              schema: %{},
              transaction_counter: 0
  end

  def start_link(opts \\ []) do
    # Start the persistence layer
    Memento.start()
    Persistence.Schema.setup()

    # Start the connection pool
    Persistence.Pool.start_link(opts)
  end

  # Schema Definition
  def define_vertex_type(state, type, properties) do
    schema =
      Map.put(state.schema, type, %{
        properties: properties,
        required: Enum.filter(properties, fn {_, opts} -> opts[:required] end) |> Keyword.keys()
      })

    %{state | schema: schema}
  end

  # Transaction Management
  def begin_transaction(state) do
    tx_id = state.transaction_counter + 1
    timestamp = System.system_time(:millisecond)

    tx = Transaction.pending([], timestamp)

    # Persist the transaction
    Persistence.persist_transaction(tx_id, tx)

    transactions = Map.put(state.transactions, tx_id, tx)
    new_state = %{state | transactions: transactions, transaction_counter: tx_id}

    {tx_id, new_state}
  end

  def commit_transaction(state, tx_id) do
    case Map.get(state.transactions, tx_id) do
      %{variant: :pending, operations: ops} ->
        # Apply operations and update graph
        {new_graph, result} = apply_operations(state.graph, Enum.reverse(ops))

        # Update transaction state with persistance
        new_tx = Transaction.committed(result, System.system_time(:millisecond))
        Persistence.persist_transaction(tx_id, new_tx)
        new_transactions = Map.put(state.transactions, tx_id, new_tx)

        # Release locks
        new_locks = release_transaction_locks(state.locks, tx_id)

        {result, %{state | graph: new_graph, transactions: new_transactions, locks: new_locks}}

      _ ->
        raise Error, "Invalid transaction state"
    end
  end

  def rollback_transaction(state, tx_id, reason \\ "User initiated rollback") do
    case Map.get(state.transactions, tx_id) do
      %{variant: :pending} ->
        timestamp = System.system_time(:millisecond)
        new_tx = Transaction.rolled_back(reason, timestamp)
        new_transactions = Map.put(state.transactions, tx_id, new_tx)
        new_locks = release_transaction_locks(state.locks, tx_id)

        {reason, %{state | transactions: new_transactions, locks: new_locks}}

      _ ->
        raise Error, "Invalid transaction state"
    end
  end

  # Graph Operations with Transactions
  def add_vertex(state, tx_id, type, id, properties) do
    with {:ok, tx} <- get_transaction(state, tx_id),
         {:ok, validated_props} <- validate_schema(state, type, properties),
         {:ok, new_state} <- acquire_vertex_lock(state, tx_id, id) do
      # persist vertex
      vertex =
        PropGraph.Graph.vertex(
          id,
          Map.put(validated_props, :type, type),
          PropGraph.Graph.empty()
        )

      Persistence.save_vertex(tx_id, vertex)

      operation = {:add_vertex, type, id, validated_props}
      new_tx = %{tx | operations: [operation | tx.operations]}
      new_transactions = Map.put(new_state.transactions, tx_id, new_tx)

      {:ok, %{new_state | transactions: new_transactions}}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  # Helper function to safely get and validate transaction
  defp get_transaction(state, tx_id) do
    case Map.get(state.transactions, tx_id) do
      %{variant: :pending} = tx -> {:ok, tx}
      nil -> {:error, "Transaction not found"}
      _ -> {:error, "Invalid transaction state"}
    end
  end

  def add_edge(state, tx_id, from_id, to_id, type, properties \\ %{}) do
    with {:ok, _} <- acquire_edge_lock(state, tx_id, from_id, to_id),
         {:ok, _} <- validate_edge(state, from_id, to_id, type) do
      # persist edge
      edge = PropGraph.Graph.edge(from_id, to_id, 1, Map.put(properties, :type, type))
      Persistence.save_edge(tx_id, edge)

      operation = {:add_edge, from_id, to_id, type, properties}
      new_transactions = update_transaction_operations(state.transactions, tx_id, operation)

      {:ok, %{state | transactions: new_transactions}}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  # Query Operations
  def query(state, pattern) do
    Logger.debug("Executing query with pattern: #{inspect(pattern)}")
    Logger.debug("Current state: #{inspect(state)}")

    results =
      fold state.graph do
        case(graph(vertex_map, edge_list, metadata)) ->
          Logger.debug("Processing graph with:")
          Logger.debug("  vertex_map: #{inspect(vertex_map)}")
          Logger.debug("  edge_list: #{inspect(edge_list)}")

          edges = extract_edges(edge_list)
          Logger.debug("Extracted edges: #{inspect(edges)}")

          results = execute_query(pattern, vertex_map, edges)
          Logger.debug("Query results: #{inspect(results)}")

          results

        case(empty()) ->
          Logger.debug("Empty graph, returning empty results")
          []
      end

    {results, state}
  end

  # Internal Functions
  defp validate_schema(state, type, properties) do
    case Map.get(state.schema, type) do
      nil ->
        {:error, "Unknown vertex type: #{type}"}

      schema ->
        # Check required properties
        missing =
          Enum.filter(schema.required, fn prop ->
            !Map.has_key?(properties, prop)
          end)

        if Enum.empty?(missing) do
          {:ok, properties}
        else
          {:error, "Missing required properties: #{inspect(missing)}"}
        end
    end
  end

  defp acquire_vertex_lock(state, tx_id, vertex_id) do
    case Map.get(state.locks, {:vertex, vertex_id}) do
      nil ->
        # Check if vertex already exists
        if Map.has_key?(state.graph.vertex_map, vertex_id) do
          {:error, "Vertex #{vertex_id} already exists"}
        else
          # No existing lock, acquire it
          new_locks = Map.put(state.locks, {:vertex, vertex_id}, tx_id)
          {:ok, %{state | locks: new_locks}}
        end

      ^tx_id ->
        # Already locked by this transaction
        {:ok, state}

      other_tx_id ->
        # Locked by another transaction
        {:error, "Vertex #{vertex_id} is locked by another transaction (tx: #{other_tx_id})"}
    end
  end

  defp acquire_edge_lock(state, tx_id, from_id, to_id) do
    edge_key = {:edge, from_id, to_id}

    case Map.get(state.locks, edge_key) do
      nil ->
        new_locks = Map.put(state.locks, edge_key, tx_id)
        {:ok, %{state | locks: new_locks}}

      ^tx_id ->
        {:ok, state}

      _ ->
        {:error, "Edge #{from_id}->#{to_id} is locked by another transaction"}
    end
  end

  defp release_transaction_locks(locks, tx_id) do
    Enum.reduce(locks, locks, fn
      {key, ^tx_id}, acc -> Map.delete(acc, key)
      _, acc -> acc
    end)
  end

  defp update_transaction_operations(transactions, tx_id, operation) do
    Map.update!(transactions, tx_id, fn
      %{variant: :pending, operations: ops, timestamp: ts} ->
        Transaction.pending([operation | ops], ts)

      _ ->
        raise Error, "Invalid transaction state"
    end)
  end

  # Update the apply_operations function to handle immediate vertex application
  defp apply_operations(graph, operations) do
    # First pass - apply all vertex operations
    {graph_with_vertices, vertex_results} =
      Enum.reduce(operations, {graph, []}, fn
        {:add_vertex, type, id, props}, {g, results} ->
          new_g = PropGraph.add_vertex(g, id, Map.put(props, :type, type))
          {new_g, [{:vertex_added, id} | results]}

        # Skip edge operations in first pass
        _, acc ->
          acc
      end)

    # Second pass - apply all edge operations
    Enum.reduce(operations, {graph_with_vertices, vertex_results}, fn
      {:add_edge, from_id, to_id, type, props}, {g, results} ->
        new_g = PropGraph.add_edge(g, from_id, to_id, 1, Map.put(props, :type, type))
        {new_g, [{:edge_added, from_id, to_id} | results]}

      # Skip vertex operations in second pass
      _, acc ->
        acc
    end)
  end

  # Add helper to extract edges from recursive structure
  defp extract_edges(edge_list) do
    Logger.debug("Extracting edges from: #{inspect(edge_list)}")

    result =
      case edge_list do
        %{variant: :edge} = single_edge ->
          Logger.debug("Single edge found")

          [single_edge]

        edges when is_list(edges) ->
          Logger.debug("Processing list of edges")

          Enum.flat_map(edges, fn
            %{variant: :edge} = edge ->
              Logger.debug("Found edge: #{inspect(edge)}")
              [edge]

            other ->
              Logger.debug("Skipping non-edge: #{inspect(other)}")
              []
          end)

        %{variant: :empty} ->
          Logger.debug("Empty edge list")
          []

        other ->
          Logger.debug("Unknown edge list format: #{inspect(other)}")
          []
      end

    Logger.debug("Extracted edges result: #{inspect(result)}")
    result
  end

  defp execute_query(pattern, vertex_map, edges) do
    Logger.debug("Executing query with pattern: #{inspect(pattern)}")

    case pattern do
      # Dynamic pattern matching for any combination of types and property maps
      [from_pattern, edge_type, to_pattern] when is_atom(edge_type) ->
        query_pattern(edges, vertex_map, {from_pattern, edge_type, to_pattern})

      _ ->
        Logger.warn("Unsupported query pattern: #{inspect(pattern)}")
        []
    end
  end

  defp query_pattern(edges, vertex_map, {from_pattern, edge_type, to_pattern}) do
    Logger.debug("""
    Querying with pattern:
      From: #{inspect(from_pattern)}
      Edge: #{inspect(edge_type)}
      To: #{inspect(to_pattern)}
    """)

    Enum.flat_map(edges, fn
      %{
        variant: :edge,
        source_id: from_id,
        target_id: to_id,
        edge_props: %{type: ^edge_type}
      } ->
        case {Map.get(vertex_map, from_id), Map.get(vertex_map, to_id)} do
          {from_vertex, to_vertex} when not is_nil(from_vertex) and not is_nil(to_vertex) ->
            if matches_pattern?(from_vertex, from_pattern) and
                 matches_pattern?(to_vertex, to_pattern) do
              Logger.debug("Found matching pattern for #{from_id} -> #{to_id}")
              [{from_id, edge_type, to_id}]
            else
              Logger.debug("Pattern match failed for #{from_id} -> #{to_id}")
              []
            end

          _ ->
            Logger.debug("Could not find vertices for #{from_id} -> #{to_id}")
            []
        end

      _ ->
        []
    end)
  end

  defp matches_pattern?(vertex, pattern) do
    case {vertex, pattern} do
      # When pattern is just a type atom
      {%{properties: %{type: type}}, pattern_type} when is_atom(pattern_type) ->
        type == pattern_type

      # When pattern is a map of properties to match
      {%{properties: props}, pattern} when is_map(pattern) ->
        Enum.all?(pattern, fn {key, value} ->
          Map.get(props, key) == value
        end)

      # No match
      _ ->
        false
    end
  end

  # Also update add_edge to check graph state rather than just vertex map
  defp validate_edge(state, from_id, to_id, _type) do
    # Check in both pending operations and current graph state
    pending_vertices = get_pending_vertices(state)
    graph_vertices = Map.keys(state.graph.vertex_map)
    all_vertices = MapSet.union(MapSet.new(pending_vertices), MapSet.new(graph_vertices))

    cond do
      !MapSet.member?(all_vertices, from_id) ->
        {:error, "Source vertex not found"}

      !MapSet.member?(all_vertices, to_id) ->
        {:error, "Target vertex not found"}

      true ->
        {:ok, {from_id, to_id}}
    end
  end

  # Add helper to get pending vertices
  defp get_pending_vertices(state) do
    state.transactions
    |> Enum.flat_map(fn {_tx_id, tx} ->
      case tx do
        %{variant: :pending, operations: ops} ->
          Enum.flat_map(ops, fn
            {:add_vertex, _type, id, _props} -> [id]
            _ -> []
          end)

        _ ->
          []
      end
    end)
  end
end
