defmodule MyTreeTest do
  use ExUnit.Case

  describe "my example" do
    test "tree creation and summing" do
      tree = MyTree.create_tree()

      # Verify structure
      assert tree.variant == :node
      assert tree.val == 0

      # Calculate sum
      total = MyTree.sum(tree)

      # The sum should be more than zero
      assert total == 8194
    end
  end
end
