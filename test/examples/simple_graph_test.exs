defmodule SimpleGraphTest do
  use ExUnit.Case
  doctest SimpleGraph

  describe "SimpleGraph" do
    test "creates a new empty graph" do
      graph = SimpleGraph.new()
      assert SimpleGraph.vertices(graph) == []
    end

    test "adds vertices" do
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        |> SimpleGraph.add_vertex(:b)
        |> SimpleGraph.add_vertex(:c)

      vertices = SimpleGraph.vertices(graph)
      assert length(vertices) == 3
      assert Enum.all?([:a, :b, :c], &(&1 in vertices))
    end

    test "adds edges between existing vertices" do
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        |> SimpleGraph.add_vertex(:b)
        |> SimpleGraph.add_vertex(:c)
        |> SimpleGraph.add_edge(:a, :b)
        |> SimpleGraph.add_edge(:b, :c)

      assert SimpleGraph.neighbors(graph, :a) == [:b]
      assert SimpleGraph.neighbors(graph, :b) == [:c]
      assert SimpleGraph.neighbors(graph, :c) == []
    end

    test "ignores edges between non-existing vertices" do
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        # b doesn't exist
        |> SimpleGraph.add_edge(:a, :b)
        # c doesn't exist
        |> SimpleGraph.add_edge(:c, :a)

      assert SimpleGraph.neighbors(graph, :a) == []
    end

    test "finds paths between vertices" do
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        |> SimpleGraph.add_vertex(:b)
        |> SimpleGraph.add_vertex(:c)
        |> SimpleGraph.add_vertex(:d)
        |> SimpleGraph.add_edge(:a, :b)
        |> SimpleGraph.add_edge(:b, :c)
        |> SimpleGraph.add_edge(:c, :d)

      assert SimpleGraph.has_path?(graph, :a, :d) == true
      assert SimpleGraph.has_path?(graph, :a, :c) == true
      assert SimpleGraph.has_path?(graph, :b, :d) == true
      # directed graph
      assert SimpleGraph.has_path?(graph, :d, :a) == false
    end

    test "handles empty graph path queries" do
      graph = SimpleGraph.new()
      assert SimpleGraph.has_path?(graph, :a, :b) == false
    end

    test "neighbors of non-existing vertex returns empty list" do
      graph = SimpleGraph.new()
      assert SimpleGraph.neighbors(graph, :nonexistent) == []
    end

    test "multiple edges between same vertices" do
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        |> SimpleGraph.add_vertex(:b)
        |> SimpleGraph.add_edge(:a, :b)
        # Adding same edge again
        |> SimpleGraph.add_edge(:a, :b)

      assert SimpleGraph.neighbors(graph, :a) == [:b, :b]
    end

    test "complex path finding" do
      # Create a more complex graph structure
      graph =
        SimpleGraph.new()
        |> SimpleGraph.add_vertex(:a)
        |> SimpleGraph.add_vertex(:b)
        |> SimpleGraph.add_vertex(:c)
        |> SimpleGraph.add_vertex(:d)
        |> SimpleGraph.add_vertex(:e)
        |> SimpleGraph.add_edge(:a, :b)
        |> SimpleGraph.add_edge(:b, :c)
        |> SimpleGraph.add_edge(:c, :d)
        |> SimpleGraph.add_edge(:b, :e)
        |> SimpleGraph.add_edge(:e, :d)

      # Test various paths
      # Can reach through b->c->d or b->e->d
      assert SimpleGraph.has_path?(graph, :a, :d) == true
      assert SimpleGraph.has_path?(graph, :a, :e) == true
      # Can't go backwards
      assert SimpleGraph.has_path?(graph, :e, :a) == false
      assert SimpleGraph.has_path?(graph, :b, :d) == true
      assert SimpleGraph.has_path?(graph, :e, :d) == true
    end
  end
end
