defmodule TreeOperations do
  import BenBen

  phrenia Tree do
    node(value, recu(left), recu(right))
    leaf()
  end

  # Creates a balanced tree of specified height with optional transform function
  def balanced_tree(height, transform_fn \\ & &1) do
    bend level = 0 do
      if level < height do
        Tree.node(
          transform_fn.(level),
          fork(level + 1),
          fork(level + 1)
        )
      else
        Tree.leaf()
      end
    end
  end

  # Maps values in the tree using a transform function
  def map_tree(tree, transform_fn) do
    fold tree do
      case(node(value, left, right)) ->
        # Don't need to transform the recursive result since recu returns the actual value
        Tree.node(transform_fn.(value), left, right)

      case(leaf()) ->
        Tree.leaf()
    end
  end

  # Filters nodes based on predicate, replacing non-matching nodes with leaves
  def filter_tree(tree, predicate) do
    fold tree do
      case(node(value, left, right)) ->
        # Similarly here, use the recursive fields directly
        if predicate.(value) do
          Tree.node(value, left, right)
        else
          # Keep subtrees even if current node doesn't match
          # Using 0 as placeholder value
          Tree.node(0, left, right)
        end

      case(leaf()) ->
        Tree.leaf()
    end
  end

  # Counts nodes at each level, returns map of level -> count
  def level_counts(tree) do
    fold tree, with: %{0 => 1} do
      case(node(value, left, right)) ->
        {_, left_counts} = recu(left)
        {_, right_counts} = recu(right)

        # Merge counts from both sides and increment levels
        new_counts =
          Map.merge(left_counts, right_counts, fn _k, v1, v2 -> v1 + v2 end)
          |> Map.new(fn {k, v} -> {k + 1, v} end)
          |> Map.put(0, 1)

        {value, new_counts}

      case(leaf()) ->
        {0, state}
    end
  end

  # Helper function to merge level counts
  defp merge_counts(left_counts, right_counts) do
    Map.merge(left_counts, right_counts, fn _k, v1, v2 -> v1 + v2 end)
  end

  # Helper to merge counts and increment levels
  defp merge_with_level_increment(left_counts, right_counts) do
    # Combine matching levels, incrementing the level numbers
    Enum.reduce(left_counts, right_counts, fn {level, count}, acc ->
      Map.update(acc, level + 1, count, &(&1 + count))
    end)
  end

  # Balances an unbalanced tree
  def balance_tree(tree) do
    # First collect all values in order
    values = collect_values(tree)
    # Then create a balanced tree with these values
    case values do
      [] ->
        Tree.leaf()

      [value] ->
        Tree.node(value, Tree.leaf(), Tree.leaf())

      values ->
        # For multiple values, ensure balanced distribution
        mid = div(length(values), 2)
        {left_values, [value | right_values]} = Enum.split(values, mid)

        Tree.node(
          value,
          build_balanced_tree(left_values),
          build_balanced_tree(right_values)
        )
    end
  end

  defp build_balanced_tree([]), do: Tree.leaf()
  defp build_balanced_tree([value]), do: Tree.node(value, Tree.leaf(), Tree.leaf())

  defp build_balanced_tree(values) do
    mid = div(length(values), 2)
    {left_values, [value | right_values]} = Enum.split(values, mid)

    Tree.node(
      value,
      build_balanced_tree(left_values),
      build_balanced_tree(right_values)
    )
  end

  # Helper to collect values in order
  defp collect_values(tree) do
    fold tree do
      case(node(value, left, right)) ->
        left_values = recu(left)
        right_values = recu(right)
        left_values ++ [value] ++ right_values

      case(leaf()) ->
        []
    end
  end
end
