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
      case(graph(vertex_map, edge_list, metadata)) ->
        Graph.graph(
          Map.put(vertex_map, id, Graph.vertex(id, props, Graph.empty())),
          edge_list,
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
      case(graph(vertex_map, edge_list, metadata)) ->
        all_edges =
          if metadata.type == :undirected do
            reverse_edge = Graph.edge(to_id, from_id, weight, props)
            [new_edge, reverse_edge]
          else
            [new_edge]
          end

        # Create new edge list without recursive processing
        new_edge_list =
          case edge_list do
            %{variant: :empty} -> hd(all_edges)
            _ -> all_edges ++ List.wrap(edge_list)
          end

        Graph.graph(vertex_map, new_edge_list, metadata)

      case(empty()) ->
        Graph.graph(%{}, new_edge, %{type: :directed})

      case(_) ->
        graph
    end
  end

  # Graph Analysis Functions
  def vertex_count(graph) do
    fold graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        map_size(vertex_map)

      case(_) ->
        0
    end
  end

  def edge_count(graph) do
    fold graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        count = count_edges(edge_list)

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
      case(graph(vertex_map, edge_list, metadata)) ->
        case Map.get(vertex_map, vertex_id) do
          nil -> []
          vertex -> extract_neighbors(edge_list, vertex_id)
        end

      case(empty()) ->
        []

      case(_) ->
        []
    end
  end

  # Helper function to extract neighbors from edge list
  defp extract_neighbors(edge_list, vertex_id) do
    case edge_list do
      %{variant: :empty} ->
        []

      %{
        variant: :edge,
        source_id: ^vertex_id,
        target_id: target_id,
        edge_weight: weight,
        edge_props: props
      } ->
        [{target_id, weight, props}]

      edges when is_list(edges) ->
        Enum.flat_map(edges, fn
          %{
            variant: :edge,
            source_id: ^vertex_id,
            target_id: target_id,
            edge_weight: weight,
            edge_props: props
          } ->
            [{target_id, weight, props}]

          _ ->
            []
        end)

      _ ->
        []
    end
  end

  # Path Finding
  def shortest_path(graph, start_id, end_id) do
    fold graph, with: {%{}, %{start_id => 0}, [start_id]} do
      case(graph(vertex_map, edge_list, metadata)) ->
        find_path(vertex_map, edge_list, start_id, end_id, state)

      case(_) ->
        {%{}, %{}, []}
    end
  end

  # Graph Properties
  def is_connected?(graph) do
    fold graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        case Map.keys(vertex_map) do
          [] ->
            true

          [first | _] = all_vertices ->
            visited = depth_first_search(vertex_map, edge_list, first, MapSet.new())
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
      current when is_list(current) -> [edge | current]
      current -> [edge, current]
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
      case(edge(source_id, target_id, edge_weight, edge_props)) ->
        if source_id == vertex.vertex_id do
          [{target_id, edge_weight, edge_props}]
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
