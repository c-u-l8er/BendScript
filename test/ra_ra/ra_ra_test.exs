defmodule RaRaTest do
  use ExUnit.Case
  require Logger

  @base_data_dir "/tmp/ra_test"

  setup_all do
    # Start the distributed system
    node_name = :"test_node@127.0.0.1"

    unless Node.alive?() do
      # Start the distributed system with a cookie
      :net_kernel.start([node_name, :shortnames])
      Node.set_cookie(:test_cookie)
    end

    Logger.debug("Started distributed node: #{inspect(Node.self())}")

    Logger.debug("Starting applications for tests")
    applications = [:ra, :sasl]

    # Ensure applications are started
    Enum.each(applications, fn app ->
      case Application.ensure_all_started(app) do
        {:ok, started} ->
          Logger.debug("Started #{app} and dependencies: #{inspect(started)}")

        {:error, error} ->
          Logger.error("Failed to start #{app}: #{inspect(error)}")
          raise "Failed to start required application: #{app}"
      end
    end)

    # Initialize Ra
    :ok = :ra.start()
    Logger.debug("Ra system started")

    # Wait for Ra to fully initialize
    Process.sleep(1000)

    on_exit(fn ->
      Logger.debug("Cleaning up test environment")
      :ra.stop()
      File.rm_rf!(@base_data_dir)
      :net_kernel.stop()
    end)

    :ok
  end

  setup do
    Logger.debug("Setting up test case")

    # Clean up data directory
    File.rm_rf!(@base_data_dir)
    File.mkdir_p!(@base_data_dir)

    # Start Registry if not already started
    case Registry.start_link(keys: :unique, name: RaRa.Registry) do
      {:ok, _pid} -> Logger.debug("Registry started")
      {:error, {:already_started, _pid}} -> Logger.debug("Registry already running")
    end

    # Define test nodes
    nodes = [:node1, :node2, :node3]

    # Start nodes with retry
    configs =
      Enum.map(nodes, fn node ->
        node_dir = Path.join(@base_data_dir, to_string(node))
        File.mkdir_p!(node_dir)

        %RaRa.Config{
          node_id: node,
          # Pass as atom instead of string
          cluster_name: "test_cluster",
          data_dir: node_dir,
          members: []
        }
      end)

    # Start each node
    started_nodes =
      Enum.map(configs, fn config ->
        case start_node_with_retry(config) do
          {:ok, _pid} = result ->
            Logger.debug("Started node #{config.node_id}")
            # Give node time to initialize
            Process.sleep(500)
            result

          error ->
            Logger.error("Failed to start node #{config.node_id}: #{inspect(error)}")
            raise "Failed to start node #{config.node_id}"
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    [first_node | other_nodes] = nodes

    # Join cluster with retries
    Enum.each(other_nodes, fn node ->
      case join_cluster_with_retry(node, first_node, 10) do
        :ok ->
          Logger.debug("Node #{node} joined cluster successfully")
          # Wait for cluster stabilization
          Process.sleep(1000)

        error ->
          Logger.error("Failed to join node #{node} to cluster: #{inspect(error)}")
          raise "Failed to join node #{node} to cluster"
      end
    end)

    # Wait for cluster to stabilize
    Process.sleep(2000)

    # Setup schema
    {:ok, tx_id} = RaRa.begin_transaction(first_node)

    :ok =
      RaRa.define_schema(
        first_node,
        tx_id,
        :person,
        name: [type: :string, required: true],
        age: [type: :integer, required: true]
      )

    {:ok, _} = RaRa.commit_transaction(first_node, tx_id)

    # Wait for schema replication
    Process.sleep(1000)

    {:ok, nodes: nodes, first_node: first_node}
  end

  test "cluster formation", %{nodes: nodes} do
    # Verify all nodes are connected
    Enum.each(nodes, fn node ->
      members = RaRa.get_cluster_members(node)
      assert length(members) == length(nodes)
    end)
  end

  test "basic transaction", %{first_node: node} do
    # Start transaction
    {:ok, tx_id} = RaRa.begin_transaction(node)

    # Add vertex
    :ok =
      RaRa.add_vertex(
        node,
        tx_id,
        :person,
        "1",
        %{name: "Alice", age: 30}
      )

    # Commit transaction
    {:ok, _} = RaRa.commit_transaction(node, tx_id)

    # Query the vertex
    {:ok, result} = RaRa.query(node, {:vertex, "1"})
    assert result.properties.name == "Alice"
    assert result.properties.age == 30
  end

  test "distributed replication", %{nodes: nodes, first_node: first_node} do
    # Create data on first node
    {:ok, tx_id} = RaRa.begin_transaction(first_node)

    :ok =
      RaRa.add_vertex(
        first_node,
        tx_id,
        :person,
        "1",
        %{name: "Bob", age: 25}
      )

    {:ok, _} = RaRa.commit_transaction(first_node, tx_id)
    # Wait for replication
    Process.sleep(500)

    # Verify data is replicated to all nodes
    Enum.each(nodes, fn node ->
      {:ok, result} = RaRa.query(node, {:vertex, "1"})
      assert result.properties.name == "Bob"
      assert result.properties.age == 25
    end)
  end

  test "schema validation", %{first_node: node} do
    {:ok, tx_id} = RaRa.begin_transaction(node)

    # Try to add vertex with missing required property
    result =
      RaRa.add_vertex(
        node,
        tx_id,
        :person,
        "1",
        # Missing required age property
        %{name: "Charlie"}
      )

    assert {:error, _message} = result

    # Clean up
    RaRa.commit_transaction(node, tx_id)
  end

  test "fault tolerance", %{nodes: [node1, node2, node3]} do
    # Create initial data
    {:ok, tx_id} = RaRa.begin_transaction(node1)

    :ok =
      RaRa.add_vertex(
        node1,
        tx_id,
        :person,
        "1",
        %{name: "Dave", age: 35}
      )

    {:ok, _} = RaRa.commit_transaction(node1, tx_id)
    Process.sleep(500)

    # Stop node2
    :ok = RaRa.stop_node(node2)
    Process.sleep(1000)

    # Verify remaining nodes can still process transactions
    {:ok, tx_id2} = RaRa.begin_transaction(node1)

    :ok =
      RaRa.add_vertex(
        node1,
        tx_id2,
        :person,
        "2",
        %{name: "Eve", age: 28}
      )

    {:ok, _} = RaRa.commit_transaction(node1, tx_id2)
    Process.sleep(500)

    # Verify node3 has the new data
    {:ok, result} = RaRa.query(node3, {:vertex, "2"})
    assert result.properties.name == "Eve"
  end

  test "node recovery", %{nodes: [node1, node2, node3]} do
    # Create initial data
    {:ok, tx_id} = RaRa.begin_transaction(node1)

    :ok =
      RaRa.add_vertex(
        node1,
        tx_id,
        :person,
        "1",
        %{name: "Frank", age: 40}
      )

    {:ok, _} = RaRa.commit_transaction(node1, tx_id)
    Process.sleep(500)

    # Stop node2
    :ok = RaRa.stop_node(node2)
    Process.sleep(1000)

    # Create more data while node2 is down
    {:ok, tx_id2} = RaRa.begin_transaction(node1)

    :ok =
      RaRa.add_vertex(
        node1,
        tx_id2,
        :person,
        "2",
        %{name: "Grace", age: 32}
      )

    {:ok, _} = RaRa.commit_transaction(node1, tx_id2)
    Process.sleep(500)

    # Restart node2
    config = %RaRa.Config{
      node_id: node2,
      cluster_name: "test_cluster",
      data_dir: "#{@base_data_dir}/node2",
      members: [node1]
    }

    {:ok, _} = RaRa.Supervisor.start_node(config)
    # Wait for recovery
    Process.sleep(2000)

    # Verify recovered node has all data
    {:ok, result1} = RaRa.query(node2, {:vertex, "1"})
    assert result1.properties.name == "Frank"

    {:ok, result2} = RaRa.query(node2, {:vertex, "2"})
    assert result2.properties.name == "Grace"
  end

  # Helper Functions

  # Add helper function for starting nodes with retry w/ config
  defp start_node_with_retry(config, retries \\ 5) do
    Logger.debug("Attempting to start node #{inspect(node)}, retries left: #{retries}")

    case RaRa.Supervisor.start_node(config) do
      {:ok, pid} = result ->
        # Verify node is actually running
        case Process.alive?(pid) do
          true ->
            Logger.debug("Node #{config.node_id} started and verified")
            result

          false ->
            if retries > 0 do
              Process.sleep(1000)
              start_node_with_retry(config, retries - 1)
            else
              {:error, :node_not_alive}
            end
        end

      error when retries > 0 ->
        Logger.warn("Failed to start node #{inspect(node)}: #{inspect(error)}, retrying...")
        Process.sleep(1000)
        start_node_with_retry(node, config, retries - 1)

      error ->
        Logger.error("Failed to start node #{inspect(node)} after all retries: #{inspect(error)}")
        error
    end
  end

  defp join_cluster_with_retry(node, target, retries \\ 5) do
    Logger.debug("""
    Attempting to join cluster:
    Node: #{inspect(node)}
    Target: #{inspect(target)}
    Retries left: #{retries}
    """)

    case RaRa.join_cluster(node, target) do
      :ok ->
        Process.sleep(500)

        if verify_cluster_membership(node, target) do
          :ok
        else
          retry_join(node, target, retries - 1)
        end

      error ->
        retry_join(node, target, retries - 1)
    end
  end

  defp retry_join(_node, _target, 0), do: {:error, :max_retries}

  defp retry_join(node, target, retries) do
    Process.sleep(1000)
    join_cluster_with_retry(node, target, retries)
  end

  defp verify_cluster_membership(node, target) do
    node_members = MapSet.new(RaRa.get_cluster_members(node))
    target_members = MapSet.new(RaRa.get_cluster_members(target))
    MapSet.equal?(node_members, target_members)
  end

  defp cleanup do
    File.rm_rf!(@base_data_dir)
  end
end
