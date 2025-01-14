defmodule CreateBinaryTreeTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  phrenia BinaryTree do
    node(val, recu(left), recu(right))
    leaf()
  end

  describe "bend operations" do
    test "creates binary tree of specified depth" do
      tree =
        bend val = 0 do
          if val < 3 do
            BinaryTree.node(val, fork(val + 1), fork(val + 1))
          else
            BinaryTree.leaf()
          end
        end

      # Verify structure
      assert tree.variant == :node
      assert tree.val == 0
      assert tree.left.val == 1
      assert tree.right.val == 1
      assert tree.left.left.val == 2
    end
  end
end
