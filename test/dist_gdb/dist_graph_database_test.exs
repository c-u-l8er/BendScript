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
      Process.sleep(200)
    end)

    # Join nodes one at a time
    [node1 | other_nodes] = node_names

    Logger.debug("Forming cluster with leader node: #{inspect(node1)}")

    # Wait for initial node to stabilize
    Process.sleep(1000)

    # Join other nodes one at a time with verification
    Enum.each(other_nodes, fn node ->
      Logger.debug("Joining node #{inspect(node)} to cluster")

      case join_cluster_with_retry(node, node1, registry_name, 15) do
        :ok ->
          Logger.debug("Node #{inspect(node)} successfully joined")
          # Wait between joins
          Process.sleep(2000)

        error ->
          raise "Failed to join node #{inspect(node)}: #{inspect(error)}"
      end
    end)

    # Wait for final cluster stabilization
    Process.sleep(2000)

    # Verify final cluster state
    Enum.each(node_names, fn node ->
      {:ok, leader} = DistGraphDatabase.get_leader(node)
      Logger.debug("Node #{inspect(node)} recognizes leader: #{inspect(leader)}")
    end)

    # Define schema for :person type
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    {:ok, _} =
      DistGraphDatabase.define_schema(
        node1,
        tx_id,
        :person,
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      )

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Wait for schema to replicate
    Process.sleep(500)

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

        case verify_cluster_size(joining_node, registry, 3) do
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

  defp verify_cluster_size(nodes, registry, expected_size, retries \\ 10) do
    Logger.debug("""
    Verifying cluster size:
    - Nodes: #{inspect(nodes)}
    - Expected size: #{expected_size}
    - Retries left: #{retries}
    """)

    if retries == 0 do
      false
    else
      all_correct_size? =
        Enum.all?(nodes, fn node ->
          case Registry.lookup(registry, node) do
            [{pid, _}] ->
              cluster_size = :sys.get_state(pid).cluster |> MapSet.size()
              # Exclude self from count for correct comparison
              actual_size = cluster_size + 1

              Logger.debug("""
              Node #{inspect(node)} cluster size:
              - Expected: #{expected_size}
              - Actual: #{actual_size}
              """)

              actual_size == expected_size

            _ ->
              Logger.debug("Node #{inspect(node)} not found in registry")
              false
          end
        end)

      if all_correct_size? do
        true
      else
        Process.sleep(1000)
        verify_cluster_size(nodes, registry, expected_size, retries - 1)
      end
    end
  end

  defp join_cluster_with_retry(node, target, registry, retries \\ 10) do
    Logger.debug("""
    Attempting to join cluster:
    Node: #{inspect(node)}
    Target: #{inspect(target)}
    Attempts left: #{retries}
    """)

    if retries <= 0 do
      {:error, :cluster_verification_failed}
    else
      case DistGraphDatabase.join_cluster(node, target) do
        :ok ->
          # Wait for cluster stabilization
          Process.sleep(1000)
          # Verify cluster membership
          case verify_cluster_membership(node, target, registry) do
            true ->
              Logger.debug("Successfully joined #{inspect(node)} to cluster")
              :ok

            false when retries > 0 ->
              Logger.debug("Cluster verification failed, retrying...")
              Process.sleep(1000)
              join_cluster_with_retry(node, target, registry, retries - 1)

            false ->
              Logger.error("Failed to verify cluster membership after all retries")
              {:error, :cluster_verification_failed}
          end

        {:error, reason} when retries > 0 ->
          Logger.debug("Join failed with reason: #{inspect(reason)}, retrying...")
          Process.sleep(1000)
          join_cluster_with_retry(node, target, registry, retries - 1)

        error ->
          Logger.error("Join failed with error: #{inspect(error)}")
          error
      end
    end
  end

  defp verify_cluster_membership(node, target, registry) do
    Logger.debug("""
    Verifying cluster membership:
    Node: #{inspect(node)}
    Target: #{inspect(target)}
    """)

    with [{pid1, _}] <- Registry.lookup(registry, node),
         [{pid2, _}] <- Registry.lookup(registry, target),
         %{cluster: cluster1} <- :sys.get_state(pid1),
         %{cluster: cluster2} <- :sys.get_state(pid2) do
      Logger.debug("""
      Cluster state:
      Node cluster: #{inspect(MapSet.to_list(cluster1))}
      Target cluster: #{inspect(MapSet.to_list(cluster2))}
      """)

      MapSet.equal?(cluster1, cluster2)
    else
      error ->
        Logger.debug("Verification failed with: #{inspect(error)}")
        false
    end
  end

  @tag :skip
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

  @tag :skip
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

  @tag :skip
  test "schema validation", %{nodes: [node1 | _]} do
    # Start transaction
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    # Try to add vertex with missing required property
    result =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice"
        # missing required age property
      })

    # Verify we get an error about missing required property
    assert {:error, message} = result
    assert message =~ "Missing required properties"

    # Clean up by rolling back the transaction
    DistGraphDatabase.commit_transaction(node1, tx_id)
  end

  @tag :skip
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

  @tag :skip
  test "node recovery", %{nodes: [node1, node2, node3], registry: registry} do
    # First verify initial cluster size
    assert verify_cluster_size([node1, node2, node3], registry, 3)

    # Create initial data
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(node1)

    {:ok, _} =
      DistGraphDatabase.add_vertex(node1, tx_id, :person, "1", %{
        name: "Alice",
        age: 30
      })

    {:ok, _} = DistGraphDatabase.commit_transaction(node1, tx_id)

    # Wait for replication
    Process.sleep(1000)

    # Verify data is replicated before stopping node2
    assert DistGraphDatabase.query(node2, {:vertex, "1"}).properties.name == "Alice"

    # Stop node2
    :ok = GenServer.stop(DistGraphDatabase.via_tuple(node2, registry))
    Process.sleep(500)

    # Restart node2
    {:ok, _} = DistGraphDatabase.start_link(node2, registry)

    # Join with retries
    :ok = join_cluster_with_retry(node2, node1, registry, 10)

    # Wait longer for recovery and replication
    Process.sleep(2000)

    # Verify cluster is back to normal
    assert verify_cluster_size([node1, node2, node3], registry, 3)

    # Verify recovered node has correct data
    result = DistGraphDatabase.query(node2, {:vertex, "1"})
    assert result.properties.name == "Alice"
  end
end
