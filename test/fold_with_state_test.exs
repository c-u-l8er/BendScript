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
          10,
          LinkedList.cons(
            20,
            LinkedList.cons(30, LinkedList.null())
          )
        )

      # Accumulate sum with state
      {_result, final_sum} =
        fold list, with: 0 do
          case(cons(head, tail)) ->
            new_sum = head + recu(tail)
            {head, new_sum}

          case(null()) ->
            {0, state}
        end

      assert final_sum == 60
    end
  end
end
