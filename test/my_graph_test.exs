defmodule MyGraphTest do
  use ExUnit.Case
  import BenBen

  describe "my example" do
    test "graph creation and summing" do
      graph = MyGraph.create_graph()

      # Verify structure
      assert graph.variant == :vertex
      # assert graph.id == 1
      # assert graph.value == 10

      # Calculate sum
      total = MyGraph.sum(graph)

      IO.puts(total)
      IO.inspect(graph)
      # The sum should include:
      # Vertex 1 (value: 10) + edges to 2,3
      # Vertex 2 (value: 20) + edges to 1,3
      # Vertex 3 (value: 30) + edges to 1,2
      # Edge weights are sum of vertex IDs
      # Replace with actual expected sum
      assert total == 12
    end
  end
end
