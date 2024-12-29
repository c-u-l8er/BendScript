defmodule FoldWithStateTest do
  use ExUnit.Case
  import BenBen

  # Define test types
  deftype LinkedList do
    cons(head, recu(tail))
    null()
  end

  describe "fold operations" do
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
            new_sum = head + recu(tail)
            {head, new_sum}

          case(null()) ->
            {0, 0}
        end

      assert final_sum == 6
    end
  end
end
