defmodule RaRa.StateMachine do
  @behaviour :ra_machine

  # Ra machine callbacks

  def init(config) do
    config
  end

  def apply(_meta, {:begin_transaction, from}, state) do
    {tx_id, new_graph_state} = GraphDatabase.begin_transaction(state.graph_state)
    effects = [{:reply, from, {:ok, tx_id}}]
    {%{state | graph_state: new_graph_state}, effects}
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

  def state_enter(_state_name, state) do
    {state, []}
  end

  # Required callback for :ra_machine
  def version do
    1
  end

  # Other required Ra machine callbacks...
end
