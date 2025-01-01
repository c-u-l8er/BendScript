defmodule DistGraphDatabase do
  use GenServer
  require Logger

  defmodule State do
    defstruct [
      # Node roles: :leader, :follower, :candidate
      role: :follower,
      # Current term number
      term: 0,
      # Leader node
      leader: nil,
      # Local graph database state
      graph_state: nil,
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
      pending_requests: %{}
    ]
  end

  # Client API
  def start_link(name, opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def join_cluster(node_name, cluster_node) do
    GenServer.call(via_tuple(node_name), {:join_cluster, cluster_node})
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

  # Server Implementation
  def init(opts) do
    state = %State{
      graph_state: %GraphDatabase.State{
        graph: LibGraph.new(:directed),
        schema: %{},
        transactions: %{},
        locks: %{},
        transaction_counter: 0
      }
    }

    {:ok, schedule_election_timeout(state)}
  end

  # Message Handling
  def handle_call({:join_cluster, cluster_node}, _from, state) do
    case :rpc.call(cluster_node, __MODULE__, :get_leader, []) do
      {:ok, leader} ->
        new_state = %{state | cluster: MapSet.put(state.cluster, cluster_node), leader: leader}
        {:reply, :ok, new_state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get_leader, _from, %{leader: leader} = state) do
    {:reply, {:ok, leader}, state}
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

  def handle_info(:heartbeat_timeout, %{role: :leader} = state) do
    broadcast_heartbeat(state)
    {:noreply, schedule_heartbeat(state)}
  end

  def handle_cast({:request_vote, term, candidate_id, last_log_index, last_log_term}, state) do
    new_state = handle_vote_request(state, term, candidate_id, last_log_index, last_log_term)
    {:noreply, new_state}
  end

  def handle_cast({:append_entries, term, leader_id, entries}, state) do
    new_state = handle_append_entries(state, term, leader_id, entries)
    {:noreply, new_state}
  end

  # Internal Functions
  defp via_tuple(name) do
    {:via, Registry, {DistGraphDatabase.Registry, name}}
  end

  defp schedule_election_timeout(state) do
    if state.election_timer, do: Process.cancel_timer(state.election_timer)
    # 150-300ms
    timeout = :rand.uniform(150) + 150
    timer = Process.send_after(self(), :election_timeout, timeout)
    %{state | election_timer: timer}
  end

  defp schedule_heartbeat(state) do
    if state.heartbeat_timer, do: Process.cancel_timer(state.heartbeat_timer)
    # 50ms heartbeat
    timer = Process.send_after(self(), :heartbeat_timeout, 50)
    %{state | heartbeat_timer: timer}
  end

  defp begin_election(state) do
    new_term = state.term + 1

    # Become candidate
    new_state = %{
      state
      | role: :candidate,
        term: new_term,
        leader: nil,
        votes: MapSet.new([node()])
    }

    # Request votes from all nodes
    last_log_index = length(state.log)
    last_log_term = if last_log_index > 0, do: List.last(state.log).term, else: 0

    Enum.each(state.cluster, fn node ->
      GenServer.cast(
        via_tuple(node),
        {:request_vote, new_term, node(), last_log_index, last_log_term}
      )
    end)

    schedule_election_timeout(new_state)
  end

  defp handle_vote_request(state, term, candidate_id, _last_log_index, _last_log_term) do
    cond do
      term < state.term ->
        # Reject vote if term is outdated
        state

      state.voted_for == nil || state.voted_for == candidate_id ->
        # Grant vote if we haven't voted or already voted for this candidate
        %{
          state
          | term: term,
            voted_for: candidate_id,
            election_timer: schedule_election_timeout(state).election_timer
        }

      true ->
        state
    end
  end

  defp handle_append_entries(state, term, leader_id, entries) do
    cond do
      term < state.term ->
        # Reject if term is outdated
        state

      true ->
        # Accept entries and update state
        new_state = %{state | term: term, leader: leader_id, role: :follower}

        # Apply entries to local state
        apply_log_entries(new_state, entries)
    end
  end

  defp replicate_log_entry(state, log_entry) do
    Enum.each(state.cluster, fn node ->
      GenServer.cast(via_tuple(node), {:append_entries, state.term, node(), [log_entry]})
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
    Enum.each(state.cluster, fn node ->
      GenServer.cast(via_tuple(node), {:append_entries, state.term, node(), []})
    end)
  end

  def query_vertices(node_name, tx_id, label) do
    GenServer.call(via_tuple(node_name), {:query_vertices, tx_id, label})
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
end
