defmodule MyTreeTest do
  use ExUnit.Case
  import BenBen

  describe "my example" do
    test "tree creation and summing" do
      tree = MyTree.create_tree()

      # Verify structure
      assert tree.variant == :node
      assert tree.id == 0
      assert tree.value == 0

      # Calculate sum
      total = MyTree.sum(tree)

      # The sum should be more than zero
      assert total > 0
    end
  end
end
