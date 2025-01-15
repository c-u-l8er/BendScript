defmodule PropGraphTest do
  use ExUnit.Case

  describe "PropGraph" do
    test "creates and modifies graphs" do
      graph =
        PropGraph.new()
        |> PropGraph.add_vertex(1, %{name: "A"})
        |> PropGraph.add_vertex(2, %{name: "B"})
        |> PropGraph.add_vertex(3, %{name: "C"})
        |> PropGraph.add_edge(1, 2, 5, %{type: "road"})
        |> PropGraph.add_edge(2, 3, 3, %{type: "road"})

      assert PropGraph.vertex_count(graph) == 3
      assert PropGraph.edge_count(graph) == 2
    end

    test "finds neighbors" do
      graph =
        PropGraph.new()
        |> PropGraph.add_vertex(1)
        |> PropGraph.add_vertex(2)
        |> PropGraph.add_edge(1, 2, 5)

      neighbors = PropGraph.get_neighbors(graph, 1)
      assert length(neighbors) == 1
      # neighbor id
      assert elem(hd(neighbors), 0) == 2
      # weight
      assert elem(hd(neighbors), 1) == 5
    end

    test "checks connectivity" do
      connected_graph =
        PropGraph.new()
        |> PropGraph.add_vertex(1)
        |> PropGraph.add_vertex(2)
        |> PropGraph.add_edge(1, 2)

      assert PropGraph.is_connected?(connected_graph)

      disconnected_graph =
        PropGraph.new()
        |> PropGraph.add_vertex(1)
        |> PropGraph.add_vertex(2)

      refute PropGraph.is_connected?(disconnected_graph)
    end

    test "finds shortest path" do
      graph =
        PropGraph.new()
        |> PropGraph.add_vertex(1)
        |> PropGraph.add_vertex(2)
        |> PropGraph.add_vertex(3)
        |> PropGraph.add_edge(1, 2, 1)
        |> PropGraph.add_edge(2, 3, 1)

      path = PropGraph.shortest_path(graph, 1, 3)
      assert path == [1, 2, 3]
    end
  end
end
