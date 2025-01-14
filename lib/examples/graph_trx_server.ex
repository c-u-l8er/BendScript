defmodule GraphTrxServer do
  require Logger
  use RegServer
  alias GraphTrx.State

  # Initialize server state
  defstate do
    %State{
      graph: LibGraph.new(),
      transactions: %{},
      locks: %{},
      schema: %{},
      transaction_counter: 0
    }
  end

  # Required callbacks for GenServer behavior
  def handle_cast(_msg, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}

  # Schema Management
  defcall(:define_vertex_type, [type, properties]) do
    Logger.debug("Defining vertex type: #{inspect(type)} with properties: #{inspect(properties)}")
    new_state = GraphTrx.define_vertex_type(state, type, properties)
    # Return both as result and state
    {new_state, new_state}
  end

  # Transaction Management
  defcall(:begin_transaction, []) do
    Logger.debug("Beginning new transaction")
    {tx_id, new_state} = GraphTrx.begin_transaction(state)
    # Return the tx_id directly, not as part of a tuple
    {tx_id, new_state}
  end

  defcall(:commit_transaction, [tx_id]) do
    Logger.debug("Committing transaction #{inspect(tx_id)}")

    try do
      {result, new_state} = GraphTrx.commit_transaction(state, tx_id)
      # Return the result directly
      {result, new_state}
    rescue
      e in GraphTrx.Error ->
        Logger.error("Commit failed: #{Exception.message(e)}")
        raise e
    end
  end

  defcall(:rollback_transaction, [tx_id, reason]) do
    Logger.debug("Rolling back transaction #{inspect(tx_id)} with reason: #{inspect(reason)}")

    try do
      {result, new_state} = GraphTrx.rollback_transaction(state, tx_id, reason)
      Logger.debug("Rollback result: #{inspect(result)}")
      {result, new_state}
    rescue
      e in GraphTrx.Error ->
        Logger.error("Rollback failed: #{Exception.message(e)}")
        raise e
    end
  end

  # Graph Operations
  defcall(:add_vertex, [tx_id, type, id, properties]) do
    Logger.debug("""
    Adding vertex:
      Transaction: #{inspect(tx_id)}
      Type: #{inspect(type)}
      ID: #{inspect(id)}
      Properties: #{inspect(properties)}
    """)

    case GraphTrx.add_vertex(state, tx_id, type, id, properties) do
      {:ok, new_state} ->
        Logger.debug("Vertex added successfully")
        {true, new_state}

      {:error, reason, new_state} ->
        Logger.debug("Failed to add vertex: #{inspect(reason)}")
        {{:error, reason}, new_state}
    end
  end

  defcall(:add_edge, [tx_id, from_id, to_id, type, properties]) do
    Logger.debug("""
    Adding edge:
      Transaction: #{inspect(tx_id)}
      From: #{inspect(from_id)}
      To: #{inspect(to_id)}
      Type: #{inspect(type)}
      Properties: #{inspect(properties)}
    """)

    case GraphTrx.add_edge(state, tx_id, from_id, to_id, type, properties) do
      {:ok, new_state} ->
        Logger.debug("Edge added successfully")
        {true, new_state}

      {:error, reason, new_state} ->
        Logger.debug("Failed to add edge: #{inspect(reason)}")
        {{:error, reason}, new_state}
    end
  end

  # Query Operations
  defcall(:query, [pattern]) do
    Logger.debug("Executing query with pattern: #{inspect(pattern)}")
    {result, new_state} = GraphTrx.query(state, pattern)
    Logger.debug("Query result: #{inspect(result)}")
    {result, new_state}
  end

  # Transaction Status
  defcall(:get_transaction, [tx_id]) do
    Logger.debug("Getting transaction #{inspect(tx_id)}")
    {tx, new_state} = {Map.get(state.transactions, tx_id), state}
    Logger.debug("Transaction state: #{inspect(tx)}")
    {tx, new_state}
  end

  # Graph Status
  defcall(:get_vertex_count, []) do
    Logger.debug("Getting vertex count")
    count = LibGraph.vertex_count(state.graph)
    Logger.debug("Vertex count: #{inspect(count)}")
    {count, state}
  end

  defcall(:get_edge_count, []) do
    Logger.debug("Getting edge count")
    count = LibGraph.edge_count(state.graph)
    Logger.debug("Edge count: #{inspect(count)}")
    {count, state}
  end

  # Client API - define header for default args
  def start_link(init_arg \\ [])
  def start_link(init_arg), do: RegServer.Server.start_link(__MODULE__, init_arg)

  # Convenience functions for client usage
  def define_vertex_type(server, type, properties) do
    call(:define_vertex_type, [type, properties], server)
  end

  def begin_transaction(server) do
    call(:begin_transaction, [], server)
  end

  def commit_transaction(server, tx_id) do
    call(:commit_transaction, [tx_id], server)
  end

  def rollback_transaction(server, tx_id, reason \\ "User initiated rollback") do
    call(:rollback_transaction, [tx_id, reason], server)
  end

  def add_vertex(server, tx_id, type, id, properties) do
    case call(:add_vertex, [tx_id, type, id, properties], server) do
      {{:error, reason}, _new_state} -> {:error, reason}
      {true, _} -> {:ok, nil}
      other -> other
    end
  end

  def add_edge(server, tx_id, from_id, to_id, type, properties \\ %{}) do
    call(:add_edge, [tx_id, from_id, to_id, type, properties], server)
  end

  def query(server, pattern) do
    call(:query, [pattern], server)
  end

  def get_transaction(server, tx_id) do
    call(:get_transaction, [tx_id], server)
  end

  def get_vertex_count(server) do
    call(:get_vertex_count, [], server)
  end

  def get_edge_count(server) do
    call(:get_edge_count, [], server)
  end

  # Helper to make calls through RegServer
  defp call(message, args, server) do
    RegServer.Server.call(server, {__MODULE__, message, args})
  end
end
