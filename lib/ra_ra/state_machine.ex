defmodule RaRa.StateMachine do
  @behaviour :ra_machine

  # Ra machine callbacks

  def init(_config) do
    %{
      graph_state: %GraphDatabase.State{
        graph: LibGraph.new(:directed),
        schema: %{},
        transactions: %{},
        locks: %{},
        transaction_counter: 0
      }
    }
  end

  def apply(_meta, {:begin_transaction, from}, state) do
    {tx_id, new_graph_state} = GraphDatabase.begin_transaction(state.graph_state)
    effects = [{:reply, from, {:ok, tx_id}}]
    {state, effects}
  end

  def apply(_meta, {:commit_transaction, tx_id, from}, state) do
    case GraphDatabase.commit_transaction(state.graph_state, tx_id) do
      {result, new_graph_state} ->
        effects = [{:reply, from, {:ok, result}}]
        {%{state | graph_state: new_graph_state}, effects}

      error ->
        effects = [{:reply, from, error}]
        {state, effects}
    end
  end

  def apply(_meta, {:add_vertex, tx_id, type, vertex_id, properties, from}, state) do
    case GraphDatabase.add_vertex(state.graph_state, tx_id, type, vertex_id, properties) do
      {:ok, new_graph_state} ->
        effects = [{:reply, from, :ok}]
        {%{state | graph_state: new_graph_state}, effects}

      {:error, reason} ->
        effects = [{:reply, from, {:error, reason}}]
        {state, effects}
    end
  end

  # Other required Ra machine callbacks...
end
