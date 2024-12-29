defmodule BenBenTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  deftype BinaryTree do
    node(val, recu(left), recu(right))
    leaf()
  end

  describe "type definitions" do
    test "creates constructor functions" do
      leaf = BinaryTree.leaf()
      node = BinaryTree.node(1, leaf, leaf)
      assert node.variant == :node
      assert node.val == 1
    end
  end
end
