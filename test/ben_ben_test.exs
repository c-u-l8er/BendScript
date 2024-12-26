defmodule BenBenTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  deftype BinaryTree do
    Node(val, ~left, ~right)
    Leaf
  end

  deftype LinkedList do
    Cons(head, ~tail)
    Nil
  end

  describe "type definitions" do
    test "creates constructor functions" do
      leaf = BinaryTree.Leaf()
      node = BinaryTree.Node(1, leaf, leaf)
      assert node.variant == :Node
      assert node.val == 1
    end
  end

  describe "fold operations" do
    test "basic sum of tree" do
      tree = BinaryTree.Node(1,
        BinaryTree.Node(2, BinaryTree.Leaf(), BinaryTree.Leaf()),
        BinaryTree.Node(3, BinaryTree.Leaf(), BinaryTree.Leaf())
      )

      sum = fold tree do
        case Node(val, left, right) -> val + ~left + ~right
        case Leaf -> 0
      end

      assert sum == 6
    end

    test "fold with state" do
      list = LinkedList.Cons(1,
        LinkedList.Cons(2,
          LinkedList.Cons(3, LinkedList.Nil())
        )
      )

      # Accumulate sum with state
      {result, final_sum} = fold list, with: 0 do
        case Cons(head, tail) ->
          new_sum = head + ~tail
          {head, new_sum}
        case Nil -> {0, 0}
      end

      assert final_sum == 6
    end
  end

  describe "bend operations" do
    test "creates binary tree of specified depth" do
      tree = bend val = 0 do
        when val < 3 do
          BinaryTree.Node(val, fork(val + 1), fork(val + 1))
        else
          BinaryTree.Leaf()
        end
      end

      # Verify structure
      assert tree.variant == :Node
      assert tree.val == 0
      assert tree.left.val == 1
      assert tree.right.val == 1
      assert tree.left.left.val == 2
    end

    test "creates linked list" do
      list = bend val = 1 do
        when val <= 3 do
          LinkedList.Cons(val, fork(val + 1))
        else
          LinkedList.Nil()
        end
      end

      # Verify structure
      assert list.variant == :Cons
      assert list.head == 1
      assert list.tail.head == 2
      assert list.tail.tail.head == 3
      assert list.tail.tail.tail.variant == :Nil
    end
  end
end
