defmodule MyGraph2Test do
  use ExUnit.Case
  alias MyGraph.MyGraph, as: ExampleGraph

  describe "my example" do
    test "can sum single vertex with edge" do
      # Create a simple vertex with one edge
      simple_graph =
        ExampleGraph.vertex(
          # id
          1,
          # value
          10,
          # edge to vertex 2 with weight 5
          ExampleGraph.edge(2, 5)
        )

      IO.puts("========")
      IO.inspect(simple_graph)
      IO.puts("========")

      total = MyGraph.sum(simple_graph)

      # vertex value (10) + edge weight (5)
      assert total == 15
    end
  end
end
