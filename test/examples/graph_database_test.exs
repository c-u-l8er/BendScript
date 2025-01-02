defmodule GraphDatabaseTest do
  use ExUnit.Case

  describe "GraphDatabase" do
    setup do
      state = %GraphDatabase.State{
        graph: LibGraph.new(:directed),
        schema: %{},
        transactions: %{},
        locks: %{},
        transaction_counter: 0
      }

      # Define schema
      state =
        GraphDatabase.define_vertex_type(state, :person,
          name: [type: :string, required: true],
          age: [type: :integer, required: true]
        )

      {:ok, state: state}
    end

    test "successful transaction", %{state: state} do
      # Begin transaction
      {tx_id, state} = GraphDatabase.begin_transaction(state)

      # Add vertices
      {:ok, state} =
        GraphDatabase.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {:ok, state} =
        GraphDatabase.add_vertex(state, tx_id, :person, "2", %{
          name: "Bob",
          age: 25
        })

      # Add edge
      {:ok, state} = GraphDatabase.add_edge(state, tx_id, "1", "2", :knows)

      # Commit transaction
      {result, state} = GraphDatabase.commit_transaction(state, tx_id)

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
      {tx_id, state} = GraphDatabase.begin_transaction(state)

      {:ok, state} =
        GraphDatabase.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice",
          age: 30
        })

      {reason, state} = GraphDatabase.rollback_transaction(state, tx_id)

      # Verify graph is unchanged
      assert LibGraph.vertex_count(state.graph) == 0
    end

    test "schema validation", %{state: state} do
      {tx_id, state} = GraphDatabase.begin_transaction(state)

      # Missing required property
      {:error, reason, state} =
        GraphDatabase.add_vertex(state, tx_id, :person, "1", %{
          name: "Alice"
        })

      assert reason =~ "Missing required properties"
    end

    test "concurrent transactions", %{state: state} do
      # Start two transactions
      {tx1, state} = GraphDatabase.begin_transaction(state)
      {tx2, state} = GraphDatabase.begin_transaction(state)

      # First transaction acquires lock
      {:ok, state} =
        GraphDatabase.add_vertex(state, tx1, :person, "1", %{
          name: "Alice",
          age: 30
        })

      # Second transaction should fail to acquire lock
      {:error, reason, _state} =
        GraphDatabase.add_vertex(state, tx2, :person, "1", %{
          name: "Bob",
          age: 25
        })

      assert reason =~ "locked by another transaction"
    end
  end
end
