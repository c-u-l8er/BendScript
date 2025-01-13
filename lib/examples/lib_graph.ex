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
    end
  end

  # Graph Analysis Functions
  def vertex_count(graph) do
    fold graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        map_size(vertex_map)

      case(empty()) ->
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

      case(empty()) ->
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
    end
  end

  # Path Finding
  def shortest_path(graph, start_id, end_id) do
    fold graph do
      case(graph(vertex_map, edge_list, metadata)) ->
        {came_from, _, _} = find_path(vertex_map, edge_list, start_id, end_id)
        reconstruct_path(came_from, end_id)

      case(empty()) ->
        []
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

      # Empty graph is considered connected
      case(empty()) ->
        true
    end
  end

  # Fix edge_count to properly count the edges
  defp count_edges(edges) do
    case edges do
      # Single edge
      %{variant: :edge} ->
        1

      # List of edges
      edges when is_list(edges) ->
        # Only count actual edge variants, not nested graph structures
        Enum.count(edges, fn
          %{variant: :edge} -> true
          _ -> false
        end)

      # Empty case
      %{variant: :empty} ->
        0

      # Default
      _ ->
        0
    end
  end

  # Fix depth_first_search to handle the map data structure
  defp depth_first_search(vertices, edges, current, visited) do
    if MapSet.member?(visited, current) do
      visited
    else
      new_visited = MapSet.put(visited, current)

      # Get neighbors from edge list
      neighbors = extract_neighbors(edges, current)

      # Only traverse neighbor vertices that exist
      Enum.reduce(neighbors, new_visited, fn {neighbor_id, _, _}, acc ->
        if Map.has_key?(vertices, neighbor_id) do
          depth_first_search(vertices, edges, neighbor_id, acc)
        else
          acc
        end
      end)
    end
  end

  # Separate the path finding logic from fold pattern matching
  defp find_path(vertex_map, edges, start_id, end_id) do
    # Initialize with start node
    initial_state = {
      # came_from
      %{},
      # distances
      %{start_id => 0},
      # queue
      [start_id]
    }

    process_queue(vertex_map, edges, end_id, initial_state)
  end

  # Process the queue until target found or queue empty
  defp process_queue(_vertices, _edges, _target, {came_from, distances, []}) do
    {came_from, distances, []}
  end

  defp process_queue(vertices, edges, target, {came_from, distances, [current | rest]} = state) do
    cond do
      current == target ->
        state

      true ->
        neighbors = extract_neighbors(edges, current)

        # Update paths for all neighbors
        {new_came_from, new_distances, new_queue} =
          Enum.reduce(neighbors, {came_from, distances, rest}, fn {next, weight, _},
                                                                  {cf, dist, q} ->
            new_dist = Map.get(dist, current, :infinity) + weight

            if new_dist < Map.get(dist, next, :infinity) do
              {
                Map.put(cf, next, current),
                Map.put(dist, next, new_dist),
                [next | q]
              }
            else
              {cf, dist, q}
            end
          end)

        process_queue(vertices, edges, target, {new_came_from, new_distances, new_queue})
    end
  end

  # Reconstruct path from came_from map
  defp reconstruct_path(came_from, current) do
    build_path(came_from, current, [])
  end

  defp build_path(came_from, current, path) do
    case Map.get(came_from, current) do
      nil -> [current | path]
      prev -> build_path(came_from, prev, [current | path])
    end
  end

  defp extract_neighbors(edges, vertex_id) do
    case edges do
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
end
