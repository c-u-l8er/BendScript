defmodule DistGraphDatabaseTest do
  use ExUnit.Case
  require Logger

  setup do
    # Use a known registry name instead of dynamic one
    registry_name = DistGraphDatabase.Registry

    # Start registry
    case Registry.start_link(keys: :unique, name: registry_name) do
      {:ok, _} -> Logger.debug("Registry started")
      {:error, {:already_started, _}} -> Logger.debug("Registry already running")
    end

    # Use fixed node names
    node_names = [:node1, :node2, :node3]

    Logger.debug("Starting nodes: #{inspect(node_names)}")

    # Start nodes sequentially
    Enum.each(node_names, fn name ->
      {:ok, _} = DistGraphDatabase.start_link(name, registry_name)
      # Give each node time to initialize
      Process.sleep(100)
    end)

    # Join nodes one at a time
    [node1 | other_nodes] = node_names

    Enum.each(other_nodes, fn node ->
      :ok = join_cluster_with_retry(node, node1, registry_name)
      # Wait for cluster to stabilize after each join
      Process.sleep(500)
    end)

    # Verify cluster size
    wait_for_cluster_size(node_names, registry_name, length(node_names))

    {:ok, nodes: node_names, registry: registry_name}
  end

  # Helper to wait for expected cluster size
  defp wait_for_cluster_size(nodes, registry, expected_size, retries \\ 10) do
    if retries == 0 do
      raise "Failed to achieve expected cluster size"
    end

    all_correct_size? =
      Enum.all?(nodes, fn node ->
        case Registry.lookup(registry, node) do
          [{pid, _}] ->
            cluster_size = :sys.get_state(pid).cluster |> MapSet.size()
            # Exclude self from count
            cluster_size == expected_size - 1

          _ ->
            false
        end
      end)

    if all_correct_size? do
      :ok
    else
      Process.sleep(1000)
      wait_for_cluster_size(nodes, registry, expected_size, retries - 1)
    end
  end

  # Helper function to join and verify cluster membership
  defp join_and_verify(joining_node, target_node, registry, retries \\ 5) do
    Logger.debug("Attempting to join #{inspect(joining_node)} to #{inspect(target_node)}")

    case DistGraphDatabase.join_cluster(joining_node, target_node) do
      :ok ->
        # Verify cluster size
        Process.sleep(200)

        case verify_cluster_size(joining_node, registry) do
          true ->
            :ok

          false when retries > 0 ->
            Process.sleep(200)
            join_and_verify(joining_node, target_node, registry, retries - 1)

          false ->
            {:error, :cluster_verification_failed}
        end

      error ->
        error
    end
  end

  defp verify_cluster_size(node_name, registry) do
    case Registry.lookup(registry, node_name) do
      [{pid, _}] ->
        cluster_size = :sys.get_state(pid).cluster |> MapSet.size()
        Logger.debug("Current cluster size for #{inspect(node_name)}: #{cluster_size}")
        cluster_size > 0

      [] ->
        false
    end
  end

  defp join_cluster_with_retry(node, target, registry, retries \\ 5) do
    case DistGraphDatabase.join_cluster(node, target) do
      :ok ->
        # Wait for cluster stabilization
        Process.sleep(1000)
        # Verify cluster membership
        case verify_cluster_membership(node, target, registry) do
          true ->
            :ok

          false when retries > 0 ->
            Process.sleep(1000)
            join_cluster_with_retry(node, target, registry, retries - 1)

          false ->
            {:error, :cluster_verification_failed}
        end

      {:error, _} when retries > 0 ->
        Process.sleep(1000)
        join_cluster_with_retry(node, target, registry, retries - 1)

      error ->
        error
    end
  end

  defp verify_cluster_membership(node, target, registry) do
    with [{pid1, _}] <- Registry.lookup(registry, node),
         [{pid2, _}] <- Registry.lookup(registry, target),
         %{cluster: cluster1} <- :sys.get_state(pid1),
         %{cluster: cluster2} <- :sys.get_state(pid2) do
      MapSet.equal?(cluster1, cluster2)
    else
      _ -> false
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
