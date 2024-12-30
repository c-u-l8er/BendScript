defmodule TreeOperationsTest do
  use ExUnit.Case
  import TreeOperations
  alias TreeOperations, as: TO

  describe "tree operations" do
    test "creates balanced tree with transform" do
      # Create tree with doubled values at each level
      tree = balanced_tree(3, &(&1 * 2))

      assert tree.value == 0
      assert tree.left.value == 2
      assert tree.right.value == 2
      assert tree.left.left.value == 4
    end

    test "maps values in tree" do
      tree = balanced_tree(2)
      mapped_tree = map_tree(tree, &(&1 * 3))

      assert mapped_tree.value == 0
      assert mapped_tree.left.value == 3
      assert mapped_tree.right.value == 3
    end

    test "filters tree nodes" do
      tree = balanced_tree(3)
      # Keep only even-level nodes
      filtered = filter_tree(tree, &(rem(&1, 2) == 0))

      assert filtered.value == 0
      assert filtered.left.variant == :leaf
      assert filtered.right.variant == :leaf
      assert filtered.left.left.value == 2
    end

    test "counts nodes at each level" do
      tree = balanced_tree(3)
      {_, counts} = level_counts(tree)

      # Root level
      assert counts[0] == 1
      # Second level
      assert counts[1] == 2
      # Third level
      assert counts[2] == 4
    end

    test "balances unbalanced tree" do
      # Create an unbalanced tree
      unbalanced =
        TO.Tree.node(
          1,
          TO.Tree.node(
            2,
            TO.Tree.node(3, TO.Tree.leaf(), TO.Tree.leaf()),
            TO.Tree.leaf()
          ),
          TO.Tree.leaf()
        )

      balanced = balance_tree(unbalanced)

      # Verify the tree is now more balanced
      {_, level_counts} = level_counts(balanced)
      max_depth = Map.keys(level_counts) |> Enum.max()

      # The maximum depth should be reduced
      assert max_depth <= 2
    end
  end
end
