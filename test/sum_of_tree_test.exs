defmodule SumOfTreeTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  deftype BinaryTree do
    node(val, recu(left), recu(right))
    leaf()
  end

  describe "fold operations" do
    test "basic sum of tree" do
      tree =
        BinaryTree.node(
          1,
          BinaryTree.node(2, BinaryTree.leaf(), BinaryTree.leaf()),
          BinaryTree.node(3, BinaryTree.leaf(), BinaryTree.leaf())
        )

      sum =
        fold tree do
          case(node(val, left, right)) -> val + recu(left) + recu(right)
          case(leaf()) -> 0
        end

      assert sum == 6
    end
  end
end
