defmodule ParentsTest do
  use ExUnit.Case
  import Parents

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

      # Root is 0
      assert filtered.value == 0
      # Level 1
      assert filtered.left.value == 0
      assert filtered.right.value == 0
      # Level 2 even numbers
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
      # Create a simple unbalanced tree
      unbalanced =
        Parents.Tree.node(
          2,
          Parents.Tree.node(
            1,
            Parents.Tree.leaf(),
            Parents.Tree.leaf()
          ),
          Parents.Tree.node(
            3,
            Parents.Tree.leaf(),
            Parents.Tree.leaf()
          )
        )

      balanced = Parents.balance_tree(unbalanced)

      # For a tree with 3 nodes, we expect:
      # - Root node (depth 0)
      # - Two child nodes (depth 1)
      assert balanced.value == 2
      assert balanced.left.value == 1
      assert balanced.right.value == 3
      assert balanced.left.left.variant == :leaf
      assert balanced.left.right.variant == :leaf
      assert balanced.right.left.variant == :leaf
      assert balanced.right.right.variant == :leaf
    end
  end
end
