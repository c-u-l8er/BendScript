defmodule GraphTrxTest do
  require Logger
  use ExUnit.Case

  setup do
    Logger.debug("Setting up test state")

    state = %GraphTrx.State{
      graph: LibGraph.new(:directed),
      schema: %{},
      transactions: %{},
      locks: %{},
      transaction_counter: 0
    }

    Logger.debug("Initial state: #{inspect(state)}")

    # Define schema
    state =
      GraphTrx.define_vertex_type(state, :person,
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      )

    Logger.debug("State after schema definition: #{inspect(state)}")
    Logger.debug("Returning context with state")
    {:ok, state: state}
  end

  describe "basic transaction operations" do
    test "successful transaction", %{state: state} do
      # Begin transaction
      {tx_id, state} = GraphTrx.begin_transaction(state)

      # Add vertices
      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "2", %{
          name: "Bob",
          age: 25
        })

      # Add edge
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "1", "2", :knows)

      # Commit transaction
      {result, state} = GraphTrx.commit_transaction(state, tx_id)

      # Verify results
      assert Enum.any?(result, fn
               {:vertex_added, "1"} -> true
               _ -> false
             end)

      assert Enum.any?(result, fn
               {:edge_added, "1", "2"} -> true
               _ -> false
             end)
    end

    test "transaction rollback", %{state: state} do
      {tx_id, state} = GraphTrx.begin_transaction(state)

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {reason, state} = GraphTrx.rollback_transaction(state, tx_id)

      # Verify graph is unchanged
      assert LibGraph.vertex_count(state.graph) == 0
    end

    test "schema validation", %{state: state} do
      {tx_id, state} = GraphTrx.begin_transaction(state)

      # Missing required property
      {:error, reason, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice"
        })

      assert reason =~ "Missing required properties"
    end

    test "concurrent transactions", %{state: state} do
      # Start two transactions
      {tx1, state} = GraphTrx.begin_transaction(state)
      {tx2, state} = GraphTrx.begin_transaction(state)

      # First transaction acquires lock
      {:ok, state} =
        GraphTrx.add_vertex(state, tx1, :person, "1", %{
          name: "Alice",
          age: 30
        })

      # Second transaction should fail to acquire lock
      {:error, reason, _state} =
        GraphTrx.add_vertex(state, tx2, :person, "1", %{
          name: "Bob",
          age: 25
        })

      assert reason =~ "locked by another transaction"
    end
  end

  describe "advanced transaction operations" do
    test "vertex operations are applied before edge validation", %{state: state} do
      Logger.debug("Initial state: #{inspect(state)}")

      # Begin transaction
      {tx_id, state} = GraphTrx.begin_transaction(state)
      Logger.debug("Transaction started with id: #{inspect(tx_id)}")

      # Add vertices
      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      Logger.debug("First vertex added, state: #{inspect(state)}")

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "2", %{
          name: "Bob",
          age: 25
        })

      # Add edge between pending vertices should succeed
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "1", "2", :knows)

      # Commit and verify
      {result, state} = GraphTrx.commit_transaction(state, tx_id)

      assert Enum.any?(result, fn
               {:edge_added, "1", "2"} -> true
               _ -> false
             end)
    end

    test "prevents adding edges to non-existent vertices", %{state: state} do
      Logger.debug("Starting edge validation test with state: #{inspect(state)}")
      {tx_id, state} = GraphTrx.begin_transaction(state)

      # Try to add edge between non-existent vertices
      {:error, reason, _state} = GraphTrx.add_edge(state, tx_id, "1", "2", :knows)
      assert reason == "Source vertex not found"
    end

    test "handles multiple transactions with vertex and edge operations", %{state: state} do
      Logger.debug("Starting multiple transactions test with state: #{inspect(state)}")

      # First transaction
      {tx1, state} = GraphTrx.begin_transaction(state)

      {:ok, state} =
        GraphTrx.add_vertex(state, tx1, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {_result, state} = GraphTrx.commit_transaction(state, tx1)

      # Second transaction
      {tx2, state} = GraphTrx.begin_transaction(state)

      {:ok, state} =
        GraphTrx.add_vertex(state, tx2, :person, "2", %{
          name: "Bob",
          age: 25
        })

      {:ok, state} = GraphTrx.add_edge(state, tx2, "1", "2", :knows)
      {result, _state} = GraphTrx.commit_transaction(state, tx2)

      assert Enum.any?(result, fn
               {:edge_added, "1", "2"} -> true
               _ -> false
             end)
    end

    test "query operations with committed data", %{state: state} do
      Logger.debug("Starting query operations test with state: #{inspect(state)}")

      # Setup test data
      {tx_id, state} = GraphTrx.begin_transaction(state)

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "2", %{
          name: "Bob",
          age: 25
        })

      {:ok, state} = GraphTrx.add_edge(state, tx_id, "1", "2", :knows)
      {_result, state} = GraphTrx.commit_transaction(state, tx_id)

      # Test query
      {results, _state} = GraphTrx.query(state, [:person, :knows, :person])
      assert length(results) > 0

      assert Enum.any?(results, fn
               {"1", :knows, "2"} -> true
               _ -> false
             end)
    end
  end
end
