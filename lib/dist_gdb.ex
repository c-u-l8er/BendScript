defmodule DistGraphDatabase do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      # Identifier
      node_name: nil,
      # Node roles: :leader, :follower, :candidate
      role: :follower,
      # Current term number
      term: 0,
      # Leader node
      leader: nil,
      # Local graph database state
      graph_state: nil,
      # registry
      registry: nil,
      # Cluster configuration
      cluster: MapSet.new(),
      # RAFT log entries
      log: [],
      # Last applied index
      commit_index: 0,
      last_applied: 0,
      # Leader state
      next_index: %{},
      match_index: %{},
      # Election timeout
      election_timer: nil,
      # Heartbeat timer
      heartbeat_timer: nil,
      # Pending requests from clients
      pending_requests: %{},
      # Voting state
      votes: MapSet.new(),
      voted_for: nil,
      # Add node_monitors field
      node_monitors: %{}
    ]
  end

  # Client API
  def start_link(name, registry_name \\ DistGraphDatabase.Registry) do
    GenServer.start_link(__MODULE__, [name, registry_name], name: via_tuple(name, registry_name))
  end

  def via_tuple(name, registry_name \\ DistGraphDatabase.Registry) do
    {:via, Registry, {registry_name, name}}
  end

  def join_cluster(node_name, cluster_node, registry_name \\ DistGraphDatabase.Registry) do
    Logger.debug("""
    Join cluster request:
    Node: #{inspect(node_name)}
    Target: #{inspect(cluster_node)}
    """)

    GenServer.call(via_tuple(node_name, registry_name), {:join_cluster, cluster_node})
  end

  def get_leader(node_name) do
    GenServer.call(via_tuple(node_name), :get_leader)
  end

  # Database Operations (forwarded to leader)
  def begin_transaction(node_name) do
    GenServer.call(via_tuple(node_name), {:begin_transaction})
  end

  def commit_transaction(node_name, tx_id) do
    GenServer.call(via_tuple(node_name), {:commit_transaction, tx_id})
  end

  def add_vertex(node_name, tx_id, type, id, properties) do
    GenServer.call(via_tuple(node_name), {:add_vertex, tx_id, type, id, properties})
  end

  def add_edge(node_name, tx_id, from_id, to_id, type, properties) do
    GenServer.call(via_tuple(node_name), {:add_edge, tx_id, from_id, to_id, type, properties})
  end

  def query(node_name, pattern) do
    GenServer.call(via_tuple(node_name), {:query, pattern})
  end

  def query_vertices(node_name, tx_id, label) do
    GenServer.call(via_tuple(node_name), {:query_vertices, tx_id, label})
  end

  # Server Implementation
  def init([name, registry_name]) do
    state = %State{
      graph_state: %GraphDatabase.State{
        graph: LibGraph.new(:directed),
        schema: %{},
        transactions: %{},
        locks: %{},
        transaction_counter: 0
      },
      # Store identifier reference
      node_name: name,
      # Store registry reference
      registry: registry_name
    }

    {:ok, schedule_election_timeout(state)}
  end

  # Message Handling
  def handle_call({:join_cluster, cluster_node}, _from, state) do
    Logger.debug("""
    Processing join cluster request:
    - Self node: #{inspect(self_name(state))}
    - Target node: #{inspect(cluster_node)}
    - Current cluster: #{inspect(MapSet.to_list(state.cluster))}
    """)

    try do
      case Registry.lookup(state.registry, cluster_node) do
        [{pid, _}] ->
          # Get existing cluster from target node
          case :sys.get_state(pid) do
            %{cluster: existing_cluster} ->
              # Create new cluster with unique membership
              new_cluster =
                MapSet.new()
                |> MapSet.put(self_name(state))
                |> MapSet.put(cluster_node)
                |> MapSet.union(existing_cluster)

              Logger.debug("New cluster membership: #{inspect(MapSet.to_list(new_cluster))}")

              new_state = %{
                state
                | cluster: new_cluster,
                  role: :follower,
                  # Store own node name
                  node_name: self_name(state)
              }

              # Notify all nodes about updated membership
              broadcast_cluster_update(new_state)

              {:reply, :ok, new_state}

            _ ->
              {:reply, {:error, :invalid_node_state}, state}
          end

        [] ->
          Logger.error("Failed to find cluster node in registry")
          {:reply, {:error, :node_not_found}, state}
      end
    catch
      :exit, reason ->
        Logger.error("Join cluster failed with: #{inspect(reason)}")
        {:reply, {:error, :node_down}, state}
    end
  end

  # Update handle_call for get_leader to be more informative
  def handle_call(:get_leader, _from, state) do
    Logger.debug("""
    Get leader request:
    - Node: #{inspect(self_name(state))}
    - Current role: #{state.role}
    - Current leader: #{inspect(state.leader)}
    - Current term: #{state.term}
    """)

    case state.role do
      :leader ->
        {:reply, {:ok, self_name(state)}, state}

      _ when not is_nil(state.leader) ->
        {:reply, {:ok, state.leader}, state}

      _ ->
        {:reply, {:error, :no_leader}, state}
    end
  end

  # Forward requests to leader if not leader
  def handle_call(request, from, %{role: role, leader: leader} = state) when role != :leader do
    if leader do
      GenServer.cast(via_tuple(leader), {:forward_request, request, from})
      {:noreply, state}
    else
      {:reply, {:error, :no_leader}, state}
    end
  end

  # Leader handles database operations
  def handle_call({:begin_transaction}, from, %{role: :leader} = state) do
    {tx_id, new_graph_state} = GraphDatabase.begin_transaction(state.graph_state)

    # Create log entry
    log_entry = %{
      term: state.term,
      index: length(state.log) + 1,
      command: {:begin_transaction, tx_id}
    }

    new_state = %{
      state
      | log: state.log ++ [log_entry],
        graph_state: new_graph_state,
        pending_requests: Map.put(state.pending_requests, log_entry.index, from)
    }

    replicate_log_entry(new_state, log_entry)
    {:noreply, new_state}
  end

  def handle_call({:commit_transaction, tx_id}, from, %{role: :leader} = state) do
    log_entry = %{
      term: state.term,
      index: length(state.log) + 1,
      command: {:commit_transaction, tx_id}
    }

    new_state = %{
      state
      | log: state.log ++ [log_entry],
        pending_requests: Map.put(state.pending_requests, log_entry.index, from)
    }

    replicate_log_entry(new_state, log_entry)
    {:noreply, new_state}
  end

  def handle_call({:query, pattern}, _from, state) do
    case pattern do
      {:vertex, id} ->
        result = GraphDatabase.query(state.graph_state, {:vertex, id})
        {:reply, result, state}

      _ ->
        {:reply, {:error, :invalid_query}, state}
    end
  end

  def handle_call({:query_vertices, _tx_id, label}, _from, state) do
    # Query vertices with matching label from graph state
    vertices = query_vertices_with_label(state.graph_state, label)
    {:reply, {:ok, vertices}, state}
  end

  def handle_call({:define_schema, _tx_id, type, properties}, _from, state) do
    new_graph_state = GraphDatabase.define_vertex_type(state.graph_state, type, properties)
    {:reply, {:ok, new_graph_state}, %{state | graph_state: new_graph_state}}
  end

  # RAFT Protocol Messages
  def handle_info(:election_timeout, state) do
    new_state = begin_election(state)
    {:noreply, new_state}
  end

  def handle_info(:heartbeat_timeout, %{role: role} = state) do
    case role do
      :leader ->
        broadcast_heartbeat(state)
        {:noreply, schedule_heartbeat(state)}

      :follower ->
        # Followers should just reset their election timeout
        {:noreply, schedule_election_timeout(state)}

      :candidate ->
        # Candidates should continue with their election
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    case Enum.find(state.node_monitors, fn {_, monitor_ref} -> monitor_ref == ref end) do
      {node, _} ->
        new_state = %{
          state
          | cluster: MapSet.delete(state.cluster, node),
            node_monitors: Map.delete(state.node_monitors, node)
        }

        {:noreply, schedule_election_timeout(new_state)}

      nil ->
        {:noreply, state}
    end
  end

  def handle_cast({:cluster_update, members}, state) do
    Logger.debug("""
    Received cluster update:
    - From: #{inspect(self_name(state))}
    - Current role: #{state.role}
    - Current term: #{state.term}
    - Current members: #{inspect(MapSet.to_list(state.cluster))}
    - New members: #{inspect(members)}
    """)

    new_cluster = MapSet.new(members)

    # Step down if we're leader and lost majority
    new_state =
      if state.role == :leader &&
           MapSet.size(new_cluster) < MapSet.size(state.cluster) do
        step_down(state, state.term)
      else
        state
      end

    # Broadcast acknowledgment
    Enum.each(members, fn node ->
      safe_cast(node, {:cluster_ack, self_name(state), new_cluster}, new_state)
    end)

    {:noreply, new_state}
  end

  def handle_cast({:cluster_ack, from_node, cluster}, state) do
    Logger.debug("""
    Received cluster ack:
    From: #{inspect(from_node)}
    Cluster: #{inspect(MapSet.to_list(cluster))}
    """)

    {:noreply, state}
  end

  def handle_cast({:node_joined, new_node}, state) do
    new_state = %{state | cluster: MapSet.put(state.cluster, new_node)}

    case add_node_monitor(new_node, new_state) do
      {:ok, monitored_state} -> {:noreply, monitored_state}
      {:error, _} -> {:noreply, new_state}
    end
  end

  def handle_cast({:request_vote, term, candidate_id, last_log_index, last_log_term}, state) do
    Logger.debug("""
    Received vote request:
    - From: #{inspect(candidate_id)}
    - Term: #{term}
    - Current term: #{state.term}
    - Current role: #{state.role}
    - Voted for: #{inspect(state.voted_for)}
    """)

    new_state = handle_vote_request(state, term, candidate_id, last_log_index, last_log_term)
    {:noreply, new_state}
  end

  def handle_cast({:append_entries, term, leader_id, entries}, state) do
    Logger.debug("""
    Received append entries:
    From: #{inspect(leader_id)}
    Term: #{term}
    Current term: #{state.term}
    Current role: #{state.role}
    """)

    new_state =
      cond do
        # If term is lower, reject
        term < state.term ->
          state

        # Step down if we see a higher term
        term > state.term ->
          step_down(state, term)
          |> Map.put(:leader, leader_id)
          |> apply_log_entries(entries)

        # If term is higher or equal, accept leader
        true ->
          %{state | term: term, leader: leader_id, role: :follower, election_timer: nil}
          |> schedule_election_timeout()
          |> apply_log_entries(entries)
      end

    {:noreply, new_state}
  end

  def handle_cast({:vote_response, term, voter_id, granted}, state) do
    Logger.debug("""
    Received vote response:
    - Self: #{inspect(self_name(state))}
    - From: #{inspect(voter_id)}
    - Term: #{term}
    - Granted: #{granted}
    - Current role: #{state.role}
    - Current term: #{state.term}
    - Current votes: #{MapSet.size(state.votes)}
    """)

    new_state = handle_vote_response(state, term, voter_id, granted)
    {:noreply, new_state}
  end

  def handle_cast({:forward_request, request, from}, state) do
    try do
      response = GenServer.call(via_tuple(state.leader, state.registry), request)
      GenServer.reply(from, response)
    catch
      :exit, _ ->
        GenServer.reply(from, {:error, :leader_down})
    end

    {:noreply, state}
  end

  # Internal Functions
  # Helper to get node name
  defp self_name(state) do
    case Registry.keys(state.registry, self()) do
      [name] -> name
      _ -> nil
    end
  end

  defp broadcast_cluster_update(state) do
    self_name = self_name(state)

    # Ensure unique membership list
    members = MapSet.to_list(MapSet.new([self_name | MapSet.to_list(state.cluster)]))

    Logger.debug("""
    Broadcasting cluster update:
    - From: #{inspect(self_name)}
    - Members: #{inspect(members)}
    """)

    # Notify all nodes about the current cluster membership
    Enum.each(state.cluster, fn node ->
      safe_cast(node, {:cluster_update, members}, state)
    end)
  end

  defp become_leader(state) do
    Logger.debug("""
    Becoming leader:
    Node: #{inspect(self_name(state))}
    Term: #{state.term}
    Cluster size: #{MapSet.size(state.cluster)}
    Votes received: #{MapSet.size(state.votes)}
    """)

    # Initialize leader state
    new_state = %{
      state
      | role: :leader,
        leader: self_name(state),
        next_index: initialize_next_index(state),
        match_index: initialize_match_index(state),
        # Clear any existing timer
        heartbeat_timer: nil,
        # Clear election timer when becoming leader
        election_timer: nil
    }

    # Start sending heartbeats immediately
    broadcast_heartbeat(new_state)
    # Schedule regular heartbeats
    schedule_heartbeat(new_state)
    new_state
  end

  defp initialize_next_index(state) do
    Enum.reduce(state.cluster, %{}, fn node, acc ->
      Map.put(acc, node, length(state.log) + 1)
    end)
  end

  defp initialize_match_index(state) do
    Enum.reduce(state.cluster, %{}, fn node, acc ->
      Map.put(acc, node, 0)
    end)
  end

  defp schedule_election_timeout(state) do
    if state.election_timer, do: Process.cancel_timer(state.election_timer)
    # Use longer timeouts with more variance (150-450ms)
    timeout = :rand.uniform(300) + 150
    timer = Process.send_after(self(), :election_timeout, timeout)
    %{state | election_timer: timer}
  end

  defp schedule_heartbeat(state) do
    if state.heartbeat_timer, do: Process.cancel_timer(state.heartbeat_timer)
    # Send heartbeats every 50ms (faster than election timeout)
    timer = Process.send_after(self(), :heartbeat_timeout, 50)
    %{state | heartbeat_timer: timer}
  end

  defp begin_election(state) do
    # Don't start new election if one is in progress
    if state.role == :candidate do
      state
    else
      new_term = state.term + 1
      self_name = self_name(state)

      Logger.debug("""
      Beginning election:
      - Node: #{inspect(self_name)}
      - New term: #{new_term}
      - Current cluster: #{inspect(MapSet.to_list(state.cluster))}
      """)

      # Include self in initial votes
      initial_votes = MapSet.new([self_name])

      # Reset election state
      new_state = %{
        state
        | role: :candidate,
          term: new_term,
          leader: nil,
          voted_for: self_name,
          votes: initial_votes,
          election_timer: nil
      }

      # Request votes from all other nodes
      Enum.each(state.cluster, fn node ->
        Logger.debug("Requesting vote from #{inspect(node)}")

        safe_cast(
          node,
          {:request_vote, new_term, self_name, length(state.log),
           if(length(state.log) > 0, do: List.last(state.log).term, else: 0)},
          new_state
        )
      end)

      # Schedule shorter election timeout
      schedule_election_timeout(new_state)
    end
  end

  defp handle_vote_request(state, term, candidate_id, last_log_index, last_log_term) do
    self_name = self_name(state)

    Logger.debug("""
    Processing vote request:
    - From candidate: #{inspect(candidate_id)}
    - Term: #{term}
    - Current term: #{state.term}
    - Current role: #{state.role}
    - Voted for: #{inspect(state.voted_for)}
    """)

    cond do
      # Step down if we see a higher term
      term > state.term ->
        new_state =
          step_down(state, term)
          |> Map.put(:voted_for, candidate_id)

        safe_cast(candidate_id, {:vote_response, term, self_name(state), true}, new_state)
        new_state

      # Same term and haven't voted
      term == state.term && (is_nil(state.voted_for) || state.voted_for == candidate_id) ->
        new_state = %{state | voted_for: candidate_id}
        safe_cast(candidate_id, {:vote_response, term, self_name(state), true}, new_state)
        schedule_election_timeout(new_state)

      # Otherwise reject
      true ->
        safe_cast(candidate_id, {:vote_response, term, self_name(state), false}, state)
        state
    end
    |> schedule_election_timeout()
  end

  # Private helper function to handle vote response logic
  defp handle_vote_response(state, term, voter_id, granted) do
    cond do
      # Step down if we see a higher term
      term > state.term ->
        step_down(state, term)

      # If we're no longer a candidate or terms don't match, ignore
      state.role != :candidate || term != state.term ->
        state

      # Vote granted
      granted ->
        new_votes = MapSet.put(state.votes, voter_id)
        total_nodes = MapSet.size(state.cluster) + 1
        votes_needed = div(total_nodes, 2) + 1

        Logger.debug("""
        Vote count update:
        - Total nodes: #{total_nodes}
        - Votes needed: #{votes_needed}
        - Current votes: #{MapSet.size(new_votes)}
        - Voters: #{inspect(MapSet.to_list(new_votes))}
        """)

        if MapSet.size(new_votes) >= votes_needed do
          Logger.debug("Won election with #{MapSet.size(new_votes)} votes")
          become_leader(%{state | votes: new_votes})
        else
          %{state | votes: new_votes}
        end

      # Vote denied
      !granted ->
        state
    end
  end

  defp replicate_log_entry(state, log_entry) do
    Enum.each(state.cluster, fn node ->
      safe_cast(node, {:append_entries, state.term, self_name(state), [log_entry]}, state)
    end)
  end

  defp apply_log_entries(state, entries) do
    Enum.reduce(entries, state, fn entry, acc_state ->
      case entry.command do
        {:begin_transaction, tx_id} ->
          {_, new_graph_state} = GraphDatabase.begin_transaction(acc_state.graph_state)
          %{acc_state | graph_state: new_graph_state}

        {:commit_transaction, tx_id} ->
          {result, new_graph_state} =
            GraphDatabase.commit_transaction(acc_state.graph_state, tx_id)

          %{acc_state | graph_state: new_graph_state}

        _ ->
          acc_state
      end
    end)
  end

  defp broadcast_heartbeat(state) do
    Logger.debug("Broadcasting heartbeat from #{inspect(self_name(state))} term: #{state.term}")

    Enum.each(state.cluster, fn node ->
      safe_cast(node, {:append_entries, state.term, self_name(state), []}, state)
    end)
  end

  defp query_vertices_with_label(graph_state, label) do
    # Implementation would depend on how vertices are stored in the graph
    # This is a simplified example
    graph_state.graph
    |> LibGraph.get_vertices()
    |> Enum.filter(fn vertex ->
      vertex.properties[:type] == String.to_atom(label)
    end)
  end

  def define_schema(node_name, tx_id, type, properties) do
    GenServer.call(via_tuple(node_name), {:define_schema, tx_id, type, properties})
  end

  # Helper to add monitors for all nodes
  defp add_cluster_monitors(cluster, state) do
    Enum.reduce(cluster, state.node_monitors, fn node, monitors ->
      case Registry.lookup(state.registry, node) do
        [{pid, _}] ->
          if Map.has_key?(monitors, node) do
            monitors
          else
            ref = Process.monitor(pid)
            Map.put(monitors, node, ref)
          end

        _ ->
          monitors
      end
    end)
  end

  # Monitor connected nodes
  defp add_node_monitor(node, state) do
    case Registry.lookup(state.registry, node) do
      [{pid, _}] ->
        ref = Process.monitor(pid)
        {:ok, %{state | node_monitors: Map.put(state.node_monitors, node, ref)}}

      [] ->
        {:error, :node_not_found}
    end
  end

  # Helper function to safely make calls to other nodes
  defp safe_call(node_name, message, state) do
    try do
      case Registry.lookup(state.registry, node_name) do
        [{pid, _}] ->
          GenServer.call(pid, message)

        [] ->
          {:error, :node_not_found}
      end
    catch
      :exit, reason ->
        Logger.error("Call to node #{node_name} failed: #{inspect(reason)}")
        {:error, :node_down}
    end
  end

  # Helper function to safely cast to other nodes
  defp safe_cast(node_name, message, state) do
    try do
      case Registry.lookup(state.registry, node_name) do
        [{pid, _}] ->
          GenServer.cast(pid, message)
          :ok

        [] ->
          {:error, :node_not_found}
      end
    catch
      :exit, reason ->
        Logger.error("Cast to node #{node_name} failed: #{inspect(reason)}")
        {:error, :node_down}
    end
  end

  defp step_down(state, term) do
    # Cancel heartbeat timer if we were leader
    if state.role == :leader and state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    %{
      state
      | term: term,
        role: :follower,
        leader: nil,
        voted_for: nil,
        votes: MapSet.new(),
        heartbeat_timer: nil
    }
    |> schedule_election_timeout()
  end

  # Add cleanup function
  def terminate(_reason, state) do
    # Clean up monitors
    Enum.each(state.node_monitors, fn {_node, ref} ->
      Process.demonitor(ref)
    end)

    # Cancel timers
    if state.election_timer, do: Process.cancel_timer(state.election_timer)
    if state.heartbeat_timer, do: Process.cancel_timer(state.heartbeat_timer)

    :ok
  end
end
