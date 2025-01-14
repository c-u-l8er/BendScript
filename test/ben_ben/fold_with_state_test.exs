defmodule FoldWithStateTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  phrenia LinkedList do
    cons(head, recu(tail))
    null()
  end

  describe "fold operations" do
    test "fold with state" do
      list = LinkedList.cons(1, LinkedList.cons(2, LinkedList.null()))

      # Accumulate sum with state
      {_result, sum} =
        fold list, with: 0 do
          case(cons(head, tail)) ->
            {tail_value, new_state} = recu(tail)
            new_sum = head + tail_value
            {head, new_sum}

          case(null()) ->
            {0, state}
        end

      assert sum == 3
    end
  end
end
