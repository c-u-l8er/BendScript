defmodule LibGraphTest do
  use ExUnit.Case

  describe "LibGraph" do
    test "creates and modifies graphs" do
      graph =
        LibGraph.new()
        |> LibGraph.add_vertex(1, %{name: "A"})
        |> LibGraph.add_vertex(2, %{name: "B"})
        |> LibGraph.add_vertex(3, %{name: "C"})
        |> LibGraph.add_edge(1, 2, 5, %{type: "road"})
        |> LibGraph.add_edge(2, 3, 3, %{type: "road"})

      assert LibGraph.vertex_count(graph) == 3
      assert LibGraph.edge_count(graph) == 2
    end

    test "finds neighbors" do
      graph =
        LibGraph.new()
        |> LibGraph.add_vertex(1)
        |> LibGraph.add_vertex(2)
        |> LibGraph.add_edge(1, 2, 5)

      neighbors = LibGraph.get_neighbors(graph, 1)
      assert length(neighbors) == 1
      # neighbor id
      assert elem(hd(neighbors), 0) == 2
      # weight
      assert elem(hd(neighbors), 1) == 5
    end

    test "checks connectivity" do
      connected_graph =
        LibGraph.new()
        |> LibGraph.add_vertex(1)
        |> LibGraph.add_vertex(2)
        |> LibGraph.add_edge(1, 2)

      assert LibGraph.is_connected?(connected_graph)

      disconnected_graph =
        LibGraph.new()
        |> LibGraph.add_vertex(1)
        |> LibGraph.add_vertex(2)

      refute LibGraph.is_connected?(disconnected_graph)
    end

    test "finds shortest path" do
      graph =
        LibGraph.new()
        |> LibGraph.add_vertex(1)
        |> LibGraph.add_vertex(2)
        |> LibGraph.add_vertex(3)
        |> LibGraph.add_edge(1, 2, 1)
        |> LibGraph.add_edge(2, 3, 1)

      path = LibGraph.shortest_path(graph, 1, 3)
      assert path == [1, 2, 3]
    end
  end
end
