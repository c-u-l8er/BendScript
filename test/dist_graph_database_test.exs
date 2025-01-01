defmodule DistGraphDatabaseTest do
  use ExUnit.Case

  setup do
    # Use a known registry name instead of dynamic one
    registry_name = DistGraphDatabase.Registry

    # Start registry if not already started
    case Registry.start_link(keys: :unique, name: registry_name) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Start nodes with unique names
    node1_name = :"node1_#{System.unique_integer([:positive])}"
    node2_name = :"node2_#{System.unique_integer([:positive])}"
    node3_name = :"node3_#{System.unique_integer([:positive])}"

    # Start nodes
    {:ok, _} = DistGraphDatabase.start_link(node1_name, registry_name)
    {:ok, _} = DistGraphDatabase.start_link(node2_name, registry_name)
    {:ok, _} = DistGraphDatabase.start_link(node3_name, registry_name)

    # Join nodes into cluster with retry
    :ok = join_cluster_with_retry(node2_name, node1_name, registry_name)
    :ok = join_cluster_with_retry(node3_name, node1_name, registry_name)

    # Wait for cluster stabilization
    Process.sleep(1000)

    # Define schema for person type
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1_name)

    {:ok, _} =
      DistGraphDatabase.define_schema(node1_name, tx_id, :person,
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      )

    {:ok, _} = DistGraphDatabase.commit_transaction(node1_name, tx_id)

    {:ok, nodes: [node1_name, node2_name, node3_name], registry: registry_name}
  end

  defp join_cluster_with_retry(node, target, registry, retries \\ 5) do
    case DistGraphDatabase.join_cluster(node, target) do
      :ok ->
        :ok

      {:error, _} when retries > 0 ->
        Process.sleep(200)
        join_cluster_with_retry(node, target, registry, retries - 1)

      error ->
        error
    end
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

  test "fault tolerance", %{nodes: [node1, node2, node3], registry: registry} do
    # Start transaction
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    # Add vertex before killing node
    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Wait for replication
    Process.sleep(200)

    # Stop node2 (instead of killing it)
    :ok = GenServer.stop(DistGraphDatabase.via_tuple(node2, registry))

    # Wait for cluster to stabilize
    Process.sleep(200)

    # Verify remaining nodes are consistent
    result1 = DistGraphDatabase.query(node1, {:vertex, "1"})
    result3 = DistGraphDatabase.query(node3, {:vertex, "1"})

    assert result1 == result3
    assert result1.properties.name == "Alice"
  end

  test "node recovery", %{nodes: [node1, node2, node3], registry: registry} do
    # Create initial data
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Wait for replication
    Process.sleep(200)

    # Stop and restart node2
    :ok = GenServer.stop(DistGraphDatabase.via_tuple(node2, registry))
    Process.sleep(100)
    {:ok, _} = DistGraphDatabase.start_link(node2, registry)
    :ok = join_cluster_with_retry(node2, node1, registry)

    # Wait for recovery
    Process.sleep(500)

    # Verify recovered node has correct data
    result = DistGraphDatabase.query(node2, {:vertex, "1"})
    assert result.properties.name == "Alice"
  end
end
