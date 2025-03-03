defmodule BridgeImo.MechaCyph.QueryBuilder do
  defstruct node: nil, where: nil, statement: nil

  def add_node(%__MODULE__{} = query_builder, node_details) do
    Logger.debug("Adding node: #{inspect(node_details)} to query: #{inspect(query_builder)}")
    %{query_builder | node: node_details}
  end

  def add_where(%__MODULE__{} = query_builder, where_condition) do
    Logger.debug("Adding where: #{inspect(where_condition)} to query: #{inspect(query_builder)}")
    %{query_builder | where: where_condition}
  end
end
