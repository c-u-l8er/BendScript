defmodule SimpleGraph do
  import KernelShtf.BenBen

  # Define our simple graph structure without weights or properties
  phrenia Graph do
    graph(vertices, recu(edges))
    edge(from, to)
    empty()
  end

  def new do
    Graph.graph(MapSet.new(), Graph.empty())
  end

  def add_vertex(graph, vertex) do
    fold graph do
      case(graph(vertices, edges)) ->
        Graph.graph(MapSet.put(vertices, vertex), edges)

      case(empty()) ->
        Graph.graph(MapSet.new([vertex]), Graph.empty())
    end
  end

  def add_edge(graph, from, to) do
    fold graph do
      case(graph(vertices, edges)) ->
        if MapSet.member?(vertices, from) and MapSet.member?(vertices, to) do
          new_edge = Graph.edge(from, to)

          case edges do
            %{variant: :empty} -> Graph.graph(vertices, new_edge)
            _ -> Graph.graph(vertices, [new_edge | List.wrap(edges)])
          end
        else
          graph
        end

      case(empty()) ->
        graph
    end
  end

  def vertices(graph) do
    fold graph do
      case(graph(vertices, edges)) -> MapSet.to_list(vertices)
      case(empty()) -> []
    end
  end

  def neighbors(graph, vertex) do
    fold graph do
      case(graph(vertices, edges)) ->
        if MapSet.member?(vertices, vertex) do
          find_neighbors(edges, vertex)
        else
          []
        end

      case(empty()) ->
        []
    end
  end

  defp find_neighbors(edges, vertex) do
    case edges do
      %{variant: :edge, from: ^vertex, to: to} ->
        [to]

      edges when is_list(edges) ->
        Enum.flat_map(edges, fn
          %{variant: :edge, from: ^vertex, to: to} -> [to]
          _ -> []
        end)

      %{variant: :empty} ->
        []
    end
  end

  def has_path?(graph, start, target) do
    fold graph do
      case(graph(vertices, edges)) ->
        if MapSet.member?(vertices, start) and MapSet.member?(vertices, target) do
          dfs(edges, start, target, MapSet.new())
        else
          false
        end

      case(empty()) ->
        false
    end
  end

  defp dfs(edges, current, target, visited) do
    cond do
      current == target ->
        true

      MapSet.member?(visited, current) ->
        false

      true ->
        new_visited = MapSet.put(visited, current)

        find_neighbors(edges, current)
        |> Enum.any?(fn neighbor ->
          dfs(edges, neighbor, target, new_visited)
        end)
    end
  end
end
