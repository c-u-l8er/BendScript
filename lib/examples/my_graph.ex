defmodule MyGraph do
  import BenBen

  deftype MyGraph do
    # edges is recursive reference
    vertex(id, value, recu(edges))
    # non-recursive edge reference
    edge(to_id, weight)
  end

  def sum(graph) do
    # Sum all vertex values and edge weights in the graph
    fold graph do
      case(vertex(_id, value, edges)) ->
        # Sum this vertex's value plus sum of all edge weights
        value + recu(edges)

      case(edge(_to_id, weight)) ->
        # For edges, just return the weight
        weight
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
    bend to_id = 1 do
      if to_id <= 3 do
        if from_id != to_id do
          # Create edge to other vertex with weight
          MyGraph.edge(to_id, from_id + to_id)
        else
          # Skip self-edges by recursing
          fork(to_id + 1)
        end
      else
        # terminating edge
        MyGraph.edge(0, 0)
      end
    end
  end
end
