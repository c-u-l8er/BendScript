defmodule Graffiti.Persistence do
  require Logger
  require Memento

  # Schema definitions for Mnesia tables
  defmodule Schema do
    use Memento.Table,
      attributes: [:id, :type, :data],
      type: :ordered_set,
      storage_type: :disc_copies

    # Table types
    @vertex_table :vertices
    @edge_table :edges
    @transaction_table :transactions
    @schema_table :schemas

    def setup do
      # Create tables if they don't exist
      Memento.Table.create(Schema)
      Memento.Table.create(@vertex_table)
      Memento.Table.create(@edge_table)
      Memento.Table.create(@transaction_table)
      Memento.Table.create(@schema_table)

      # Add indexes
      :mnesia.add_table_index(@vertex_table, :type)
      :mnesia.add_table_index(@edge_table, :type)
    end
  end

  # Pool configuration for Graffiti workers
  defmodule Pool do
    use Supervisor

    def start_link(opts) do
      Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
    end

    def init(opts) do
      pool_opts = [
        name: {:local, :graph_pool},
        worker_module: Graffiti.Worker,
        size: opts[:pool_size] || 5,
        max_overflow: opts[:max_overflow] || 2
      ]

      children = [
        :poolboy.child_spec(:graph_pool, pool_opts, opts)
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end

  # Worker module for handling graph operations
  defmodule Worker do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      {:ok, %{graph: PropGraph.new()}}
    end

    # Handle graph operations in a pooled worker
    def handle_call({:execute, operation, args}, _from, state) do
      result = apply(Graffiti, operation, [state.graph | args])
      {:reply, result, state}
    end
  end

  # API for persistence operations
  def save_vertex(tx_id, vertex) do
    Memento.transaction(fn ->
      Memento.Query.write(%Schema{
        id: vertex.vertex_id,
        type: :vertex,
        data: :erlang.term_to_binary(vertex)
      })
    end)
  end

  def save_edge(tx_id, edge) do
    Memento.transaction(fn ->
      Memento.Query.write(%Schema{
        id: {edge.source_id, edge.target_id},
        type: :edge,
        data: :erlang.term_to_binary(edge)
      })
    end)
  end

  def load_vertex(id) do
    Memento.transaction(fn ->
      case Memento.Query.read(Schema, id) do
        %Schema{type: :vertex, data: data} -> :erlang.binary_to_term(data)
        nil -> nil
      end
    end)
  end

  def load_edge(source_id, target_id) do
    Memento.transaction(fn ->
      case Memento.Query.read(Schema, {source_id, target_id}) do
        %Schema{type: :edge, data: data} -> :erlang.binary_to_term(data)
        nil -> nil
      end
    end)
  end

  # Transaction management with persistence
  def persist_transaction(tx_id, transaction) do
    Memento.transaction(fn ->
      Memento.Query.write(%Schema{
        id: tx_id,
        type: :transaction,
        data: :erlang.term_to_binary(transaction)
      })
    end)
  end

  def load_transaction(tx_id) do
    Memento.transaction(fn ->
      case Memento.Query.read(Schema, tx_id) do
        %Schema{type: :transaction, data: data} -> :erlang.binary_to_term(data)
        nil -> nil
      end
    end)
  end
end
