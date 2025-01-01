defmodule DistGraphDatabaseTest do
  use ExUnit.Case

  setup do
    # Start registry for distributed nodes
    {:ok, _} = Registry.start_link(keys: :unique, name: DistGraphDatabase.Registry)

    # Start three nodes
    {:ok, node1} = DistGraphDatabase.start_link(:node1)
    {:ok, node2} = DistGraphDatabase.start_link(:node2)
    {:ok, node3} = DistGraphDatabase.start_link(:node3)

    # Join nodes into cluster
    :ok = DistGraphDatabase.join_cluster(:node2, :node1)
    :ok = DistGraphDatabase.join_cluster(:node3, :node1)

    # Wait for leader election
    Process.sleep(500)

    # Define schema for person type
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(:node1)

    {:ok, _} =
      DistGraphDatabase.define_schema(:node1, tx_id, :person,
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      )

    {:ok, _} = DistGraphDatabase.commit_transaction(:node1, tx_id)

    {:ok, nodes: [:node1, :node2, :node3]}
  end

  test "leader election", %{nodes: nodes} do
    # Verify that exactly one leader exists
    leaders =
      Enum.map(nodes, fn node ->
        {:ok, leader} = DistGraphDatabase.get_leader(node)
        leader
      end)
      |> Enum.uniq()

    assert length(leaders) == 1
  end

  test "distributed transaction", %{nodes: [node1 | _] = nodes} do
    # Start transaction on any node
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    # Add vertex
    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    # Commit transaction
    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Wait for replication
    Process.sleep(100)

    # Verify data is replicated to all nodes
    Enum.each(nodes, fn node ->
      # Query vertex on each node
      result = DistGraphDatabase.query(node, {:vertex, "1"})
      assert result != nil
      assert result.properties.name == "Alice"
    end)
  end

  test "schema validation", %{nodes: [node1 | _]} do
    # Start transaction
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    # Try to add vertex with missing required property
    result =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice"
        # missing required age property
      })

    assert {:error, _message} = result
  end

  test "fault tolerance", %{nodes: [node1, node2, node3]} do
    # Start transaction
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    # Kill one node
    Process.exit(Process.whereis(:node2), :kill)

    # Continue with transaction
    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Verify remaining nodes are consistent
    Process.sleep(100)

    result1 = DistGraphDatabase.query(node1, {:vertex, "1"})
    result3 = DistGraphDatabase.query(node3, {:vertex, "1"})

    assert result1 == result3
  end

  test "node recovery", %{nodes: [node1, node2, node3]} do
    # Create data before killing node
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Kill and restart node2
    Process.exit(Process.whereis(:node2), :kill)
    {:ok, _} = DistGraphDatabase.start_link(:node2)
    :ok = DistGraphDatabase.join_cluster(:node2, :node1)

    # Wait for recovery
    Process.sleep(200)

    # Verify recovered node has correct data
    result = DistGraphDatabase.query(node2, {:vertex, "1"})
    assert result.properties.name == "Alice"
  end
end
