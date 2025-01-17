defmodule CreateLinkedListTest do
  use ExUnit.Case
  import KernelShtf.BenBen

  # Define test types
  phrenia LinkedList do
    cons(head, recu(tail))
    null()
  end

  describe "bend operations" do
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
