defmodule BenBenTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  deftype BinaryTree do
    node(val, @left, @right)
    leaf()
  end

  deftype LinkedList do
    cons(head, @tail)
    null()
  end

  describe "type definitions" do
    test "creates constructor functions" do
      leaf = BinaryTree.leaf()
      node = BinaryTree.node(1, leaf, leaf)
      assert node.variant == :node
      assert node.val == 1
    end
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
          case(node(val, left, right)) -> val + @left + @right
          case(leaf()) -> 0
        end

      assert sum == 6
    end

    test "fold with state" do
      list =
        LinkedList.cons(
          1,
          LinkedList.cons(
            2,
            LinkedList.cons(3, LinkedList.null())
          )
        )

      # Accumulate sum with state
      {_result, final_sum} =
        fold list, with: 0 do
          case(cons(head, tail)) ->
            new_sum = head + @tail
            {head, new_sum}

          case(null()) ->
            {0, 0}
        end

      assert final_sum == 6
    end
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

    test "creates linked list" do
      list =
        bend val = 1 do
          if val <= 3 do
            LinkedList.cons(val, fork(val + 1))
          else
            LinkedList.null()
          end
        end

      # Verify structure
      assert list.variant == :cons
      assert list.head == 1
      assert list.tail.head == 2
      assert list.tail.tail.head == 3
      assert list.tail.tail.tail.variant == :null
    end
  end
end
