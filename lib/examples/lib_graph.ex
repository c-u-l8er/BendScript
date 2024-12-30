defmodule LibGraph do
  import BenBen

  deftype Graph do
    # Each variant with unique field names
    graph(vertex_map, recu(edge_list), metadata)
    vertex(vertex_id, properties, recu(adjacency))
    edge(source_id, target_id, edge_weight, edge_props)
    empty()
  end

  # Core Graph Operations
  def new(type \\ :directed) do
    Graph.graph(
      # Empty vertices map
      %{},
      # Empty edges
      Graph.empty(),
      # Metadata with graph type
      %{type: type}
    )
  end

  def add_vertex(graph, id, props \\ %{}) do
    fold graph do
      case(graph(vertices, edges, metadata)) ->
        Graph.graph(
          Map.put(vertices, id, Graph.vertex(id, props, Graph.empty())),
          edges,
          metadata
        )

      # Add handling for empty variant
      case(empty()) ->
        Graph.graph(
          %{id => Graph.vertex(id, props, Graph.empty())},
          Graph.empty(),
          %{type: :directed}
        )

      case(_) ->
        graph
    end
  end

  def add_edge(graph, from_id, to_id, weight \\ 1, props \\ %{}) do
    new_edge = Graph.edge(from_id, to_id, weight, props)

    fold graph do
      case(graph(vertices, edges, metadata)) ->
        # For undirected graphs, add reverse edge
        all_edges =
          if metadata.type == :undirected do
            reverse_edge = Graph.edge(to_id, from_id, weight, props)
            [new_edge, reverse_edge]
          else
            [new_edge]
          end

        Graph.graph(
          vertices,
          Enum.reduce(all_edges, edges, &add_edge_to_list/2),
          metadata
        )

      case(empty()) ->
        # Handle empty graph case
        Graph.graph(%{}, [new_edge], %{type: :directed})

      case(_) ->
        graph
    end
  end

  # Graph Analysis Functions
  def vertex_count(graph) do
    fold graph do
      case(graph(vertices, edges, metadata)) ->
        map_size(vertices)

      case(_) ->
        0
    end
  end

  def edge_count(graph) do
    fold graph do
      case(graph(vertices, edges, metadata)) ->
        count = count_edges(edges)

        if metadata.type == :undirected do
          # Don't count both directions
          div(count, 2)
        else
          count
        end

      case(_) ->
        0
    end
  end

  def get_neighbors(graph, vertex_id) do
    fold graph do
      case(graph(vertices, edges, metadata)) ->
        case Map.get(vertices, vertex_id) do
          nil -> []
          vertex -> get_adjacent_vertices(vertex, edges)
        end

      case(empty()) ->
        []

      case(_) ->
        []
    end
  end

  # Path Finding
  def shortest_path(graph, start_id, end_id) do
    fold graph, with: {%{}, %{start_id => 0}, [start_id]} do
      case(graph(vertices, edges, metadata)) ->
        find_path(vertices, edges, start_id, end_id, state)

      case(_) ->
        {%{}, %{}, []}
    end
  end

  # Graph Properties
  def is_connected?(graph) do
    fold graph do
      case(graph(vertices, edges, metadata)) ->
        case Map.keys(vertices) do
          [] ->
            true

          [first | _] = all_vertices ->
            visited = depth_first_search(vertices, edges, first, MapSet.new())
            MapSet.size(visited) == length(all_vertices)
        end

      case(_) ->
        true
    end
  end

  # Helper Functions
  defp add_edge_to_list(edge, edges) do
    case edges do
      %{variant: :empty} -> edge
      current -> [edge | List.wrap(current)]
    end
  end

  defp count_edges(edges) do
    fold edges do
      case(edge(source_id, target_id, edge_weight, edge_props)) ->
        1 +
          fold edges do
            case(edge(source_id, target_id, edge_weight, edge_props)) -> 1
            case(empty()) -> 0
          end

      case(empty()) ->
        0
    end
  end

  defp get_adjacent_vertices(vertex, edges) do
    fold edges do
      case(edge(source_id, target_id, weight, props)) ->
        if source_id == vertex.vertex_id do
          [{target_id, weight, props}]
        else
          []
        end

      case(empty()) ->
        []

      case(_) ->
        []
    end
    |> List.flatten()
  end

  defp depth_first_search(vertices, edges, current, visited) do
    if MapSet.member?(visited, current) do
      visited
    else
      new_visited = MapSet.put(visited, current)
      neighbors = get_neighbors(%{vertices: vertices, edges: edges}, current)

      Enum.reduce(neighbors, new_visited, fn {neighbor_id, _, _}, acc ->
        depth_first_search(vertices, edges, neighbor_id, acc)
      end)
    end
  end

  defp find_path(vertices, edges, current, target, {came_from, distances, queue}) do
    if current == target or Enum.empty?(queue) do
      reconstruct_path(came_from, target)
    else
      [current | rest] = queue
      neighbors = get_neighbors(%{vertices: vertices, edges: edges}, current)

      Enum.reduce(neighbors, {came_from, distances, rest}, fn {next, weight, _}, acc ->
        update_path(current, next, weight, acc)
      end)
    end
  end

  defp update_path(current, next, weight, {came_from, distances, queue}) do
    new_dist = Map.get(distances, current, :infinity) + weight

    if new_dist < Map.get(distances, next, :infinity) do
      {
        Map.put(came_from, next, current),
        Map.put(distances, next, new_dist),
        [next | queue]
      }
    else
      {came_from, distances, queue}
    end
  end

  defp reconstruct_path(came_from, target) do
    build_path(came_from, target, [])
  end

  defp build_path(came_from, current, path) do
    case Map.get(came_from, current) do
      nil -> [current | path]
      prev -> build_path(came_from, prev, [current | path])
    end
  end
end
