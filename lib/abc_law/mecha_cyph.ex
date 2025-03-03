defmodule MechaCyph do
  use KernelShtf.Gov
  require Logger

  alias Graffiti
  alias PropGraph
  alias BridgeImo.MechaCyph.QueryBuilder

  fabric MechaCyph do
    def canvas(opts) do
      # initial state for query
      {:ok, %{memory: :initial, rotate: %{query: %QueryBuilder{}}}}
    end

    pattern :initial do
      weave :create do
        Logger.debug("Transitioning from initial to create")
        weft(to: :create, drum: drum)
      end

      weave :match do
        Logger.debug("Transitioning from initial to match")
        weft(to: :match, drum: drum)
      end
    end

    pattern :create do
      weave {:node, node_details} do
        new_rotate = Map.put(drum.rotate, :node, node_details)
        new_rotate = Map.put(new_rotate, :operation, :create)

        new_rotate =
          Map.put(new_rotate, :query, QueryBuilder.add_node(new_rotate.query, node_details))

        Logger.debug("NODE details: #{inspect(new_rotate)}")
        warp(drum: %{drum | rotate: new_rotate})
      end

      weave :return do
        Logger.debug("CREATING and RETURNING")
        weft(to: :return, drum: drum)
      end
    end

    pattern :match do
      weave {:node, node_details} do
        new_rotate = Map.put(drum.rotate, :node, node_details)
        new_rotate = Map.put(new_rotate, :operation, :match)

        new_rotate =
          Map.put(new_rotate, :query, QueryBuilder.add_node(new_rotate.query, node_details))

        Logger.debug("NODE details: #{inspect(new_rotate)}")
        warp(drum: %{drum | rotate: new_rotate})
      end

      weave :where do
        Logger.debug("TRANSITION to where")
        weft(to: :where, drum: drum)
      end

      weave :return do
        Logger.debug("Match and RETURNING")
        weft(to: :return, drum: drum)
      end
    end

    pattern :where do
      weave {:filter, filter_condition} do
        Logger.debug("Adding filter condition: #{inspect(filter_condition)}")
        new_rotate = Map.put(drum.rotate, :filter, filter_condition)

        new_rotate =
          Map.put(new_rotate, :query, QueryBuilder.add_where(new_rotate.query, filter_condition))

        warp(drum: %{drum | rotate: new_rotate})
      end

      weave :return do
        Logger.debug("WHERE and RETURNING")
        weft(to: :return, drum: drum)
      end
    end

    pattern :return do
      weave :build_and_execute do
        Logger.debug("Building and executing query!")
        weft(to: :executed, drum: drum)
      end
    end

    pattern :executed do
      # This state would handle executing the query and returning the results
    end
  end

  # API functions
  def cypher(pid, command) do
    GenServer.call(pid, {:cypher, command})
  end

  def create(pid) do
    GenServer.call(pid, {:drum, :initial, :create})
  end

  def match(pid) do
    GenServer.call(pid, {:drum, :initial, :match})
  end

  def node(pid, node_details) do
    Logger.debug("Sending {:node, #{inspect(node_details)}} to MechaCyph")

    case get_drum(pid) do
      %{memory: :create} ->
        GenServer.call(pid, {:drum, :create, {:node, node_details}})

      %{memory: :match} ->
        GenServer.call(pid, {:drum, :match, {:node, node_details}})

      %{memory: :initial} ->
        {:error, "Must first call `create` or `match`."}

      _ ->
        {:error, "Unexpected state"}
    end
  end

  def where(pid, filter_condition) do
    Logger.debug("Sending filter condition to WHERE for query: #{inspect(filter_condition)}")
    GenServer.call(pid, {:drum, :match, :where})
    GenServer.call(pid, {:drum, :where, {:filter, filter_condition}})
  end

  def return(pid) do
    Logger.debug("return triggered")

    case get_drum(pid) do
      %{memory: :create} ->
        Logger.debug("RETURN create")
        GenServer.call(pid, {:drum, :create, :return})
        GenServer.call(pid, {:drum, :return, :build_and_execute})

      %{memory: :match} ->
        Logger.debug("RETURN match")
        GenServer.call(pid, {:drum, :match, :return})
        GenServer.call(pid, {:drum, :return, :build_and_execute})

      _ ->
        {:error, "Unexpected state"}
    end
  end

  def execute_query(pid, graph_state) do
    Logger.debug("EXECUT QUERY")
    {:ok, drum} = get_drum(pid)
    query_map = drum.rotate.query
    Logger.debug("EXECUTING the query #{inspect(query_map)}")
    {:ok, {results, new_graph_state}} = Graffiti.query(graph_state, query_map)
    {:ok, new_graph_state}
  end
end
