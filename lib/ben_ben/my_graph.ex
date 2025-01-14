defmodule MyGraph do
  import BenBen

  phrenia MyGraph do
    # edges is recursive reference
    vertex(id, value, recu(edges))
    # non-recursive edge reference
    edge(to_id, weight)
  end

  def sum(graph) do
    # Sum all vertex values and edge weights in the graph
    fold graph do
      case(vertex(id, value, edges)) ->
        value + recu(edges)

      case(edge(to_id, weight)) ->
        # For edges, handle both regular and terminal cases
        if to_id == 0 and weight == 0 do
          0
        else
          weight
        end
    end
  end

  def create_graph do
    # Create a simple graph with 3 vertices and interconnecting edges
    bend vertex_id = 1 do
      if vertex_id <= 3 do
        # Create vertex with edges to other vertices
        MyGraph.vertex(
          vertex_id,
          # vertex value
          vertex_id * 10,
          create_edges(vertex_id)
        )
      else
        # End recursion by creating an empty edge list
        # terminating edge
        MyGraph.edge(0, 0)
      end
    end
  end

  # Helper function to create edges for each vertex
  defp create_edges(from_id) do
    # Create an edge directly
    MyGraph.edge(
      if from_id < 3 do
        # Connect to next vertex
        from_id + 1
      else
        # Terminal edge for last vertex
        0
      end,
      if from_id < 3 do
        # Weight based on source vertex
        from_id * 2
      else
        # Terminal weight
        0
      end
    )
  end
end
