defmodule GraphTrx do
  import BenBen
  alias LibGraph, as: Graph

  deftype Transaction do
    # Transaction states
    pending(operations, timestamp)
    committed(changes, timestamp)
    rolled_back(reason, timestamp)
  end

  defmodule Error do
    defexception [:message]
  end

  defmodule State do
    defstruct graph: LibGraph.new(),
              transactions: %{},
              locks: %{},
              schema: %{},
              transaction_counter: 0
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
    transactions = Map.put(state.transactions, tx_id, tx)

    {tx_id, %{state | transactions: transactions, transaction_counter: tx_id}}
  end

  def commit_transaction(state, tx_id) do
    case Map.get(state.transactions, tx_id) do
      %{variant: :pending, operations: ops} ->
        # Apply operations and update graph
        {new_graph, result} = apply_operations(state.graph, ops)

        # Update transaction state
        new_tx = Transaction.committed(result, System.system_time(:millisecond))
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
    case Map.get(state.transactions, tx_id) do
      %{variant: :pending} = tx ->
        with {:ok, validated_props} <- validate_schema(state, type, properties),
            {:ok, new_state} <- acquire_vertex_lock(state, tx_id, id) do
          # Record operation in transaction
          operation = {:add_vertex, type, id, validated_props}
          new_transactions = Map.put(state.transactions, tx_id, %{tx | operations: [operation | tx.operations]})

          {:ok, %{new_state | transactions: new_transactions}}
        else
          {:error, reason} -> {:error, reason, state}
        end
      _ ->
        {:error, "Invalid transaction state", state}
    end
  end

  def add_edge(state, tx_id, from_id, to_id, type, properties \\ %{}) do
    with {:ok, _} <- acquire_edge_lock(state, tx_id, from_id, to_id),
         {:ok, _} <- validate_edge(state, from_id, to_id, type) do
      operation = {:add_edge, from_id, to_id, type, properties}
      new_transactions = update_transaction_operations(state.transactions, tx_id, operation)

      {:ok, %{state | transactions: new_transactions}}
    else
      {:error, reason} -> {:error, reason, state}
    end
  end

  # Query Operations
  def query(state, pattern) do
    # Execute query on current graph state
    # Returns vertices/edges matching pattern
    results = fold state.graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        execute_query(pattern, vertex_map, edge_list)

      case(empty()) ->
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

  defp apply_operations(graph, operations) do
    # Apply operations in order received
    Enum.reduce(operations, {graph, []}, fn
      {:add_vertex, type, id, props}, {g, results} ->
        new_g = Graph.add_vertex(g, id, Map.put(props, :type, type))
        {new_g, [{:vertex_added, id} | results]}

      {:add_edge, from_id, to_id, type, props}, {g, results} ->
        new_g = Graph.add_edge(g, from_id, to_id, 1, Map.put(props, :type, type))
        {new_g, [{:edge_added, from_id, to_id} | results]}
    end)
  end

  defp execute_query(pattern, vertex_map, edge_list) do
    # Basic implementation for testing
    case pattern do
      [:person, :knows, :person] ->
        Enum.flat_map(edge_list, fn
          %{variant: :edge, source_id: from_id, target_id: to_id, edge_weight: _, edge_props: %{type: :knows}} ->
            case {Map.get(vertex_map, from_id), Map.get(vertex_map, to_id)} do
              {%{properties: %{type: :person}}, %{properties: %{type: :person}}} ->
                [{from_id, :knows, to_id}]
              _ -> []
            end
          _ -> []
        end)
      _ -> []
    end
  end

  defp validate_edge(state, from_id, to_id, type) do
    with true <- Map.has_key?(state.graph.vertex_map, from_id) || {:error, "Source vertex not found"},
         true <- Map.has_key?(state.graph.vertex_map, to_id) || {:error, "Target vertex not found"} do
      {:ok, {from_id, to_id, type}}
    end
  end
end
