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

  describe "advanced query operations" do
    setup %{state: state} do
      # Setup more complex test data
      {tx_id, state} = GraphTrx.begin_transaction(state)

      # Define additional vertex types
      state =
        GraphTrx.define_vertex_type(state, :company,
          name: [type: :string, required: true],
          industry: [type: :string, required: true]
        )

      state =
        GraphTrx.define_vertex_type(state, :project,
          name: [type: :string, required: true],
          status: [type: :string, required: true]
        )

      # Add vertices
      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "p1", %{
          name: "Alice",
          age: 30,
          role: "Developer"
        })

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :person, "p2", %{
          name: "Bob",
          age: 25,
          role: "Manager"
        })

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :company, "c1", %{
          name: "TechCorp",
          industry: "Software"
        })

      {:ok, state} =
        GraphTrx.add_vertex(state, tx_id, :project, "proj1", %{
          name: "GraphDB",
          status: "Active"
        })

      # Add various relationship types
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "p1", "p2", :knows)
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "p1", "c1", :works_at)
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "p2", "c1", :works_at)
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "p1", "proj1", :works_on)
      {:ok, state} = GraphTrx.add_edge(state, tx_id, "c1", "proj1", :owns)

      {_result, state} = GraphTrx.commit_transaction(state, tx_id)

      {:ok, state: state}
    end

    test "queries with different vertex types", %{state: state} do
      # Test person-knows-person relationship
      {results, _} = GraphTrx.query(state, [:person, :knows, :person])
      assert length(results) == 1
      assert Enum.member?(results, {"p1", :knows, "p2"})

      # Test person-works_at-company relationship
      {results, _} = GraphTrx.query(state, [:person, :works_at, :company])
      assert length(results) == 2
      assert Enum.member?(results, {"p1", :works_at, "c1"})
      assert Enum.member?(results, {"p2", :works_at, "c1"})

      # Test company-owns-project relationship
      {results, _} = GraphTrx.query(state, [:company, :owns, :project])
      assert length(results) == 1
      assert Enum.member?(results, {"c1", :owns, "proj1"})
    end

    test "queries with property filters", %{state: state} do
      # Query for developers working at software companies
      {results, _} =
        GraphTrx.query(state, [
          %{role: "Developer"},
          :works_at,
          %{industry: "Software"}
        ])

      assert length(results) == 1
      assert Enum.member?(results, {"p1", :works_at, "c1"})

      # Query for managers working on active projects
      {results, _} =
        GraphTrx.query(state, [
          %{role: "Manager"},
          :works_on,
          %{status: "Active"}
        ])

      # Bob (manager) doesn't work directly on projects
      assert length(results) == 0
    end

    test "queries with non-existent patterns", %{state: state} do
      # Query for a relationship type that doesn't exist
      {results, _} = GraphTrx.query(state, [:person, :reports_to, :person])
      assert results == []

      # Query with non-existent property values
      {results, _} =
        GraphTrx.query(state, [
          %{role: "Designer"},
          :works_at,
          %{industry: "Software"}
        ])

      assert results == []
    end

    test "queries with mixed vertex types and properties", %{state: state} do
      # Query for any person working at software companies
      {results, _} =
        GraphTrx.query(state, [
          :person,
          :works_at,
          %{industry: "Software"}
        ])

      assert length(results) == 2

      # Query for developers working at any company
      {results, _} =
        GraphTrx.query(state, [
          %{role: "Developer"},
          :works_at,
          :company
        ])

      assert length(results) == 1
    end
  end
end
