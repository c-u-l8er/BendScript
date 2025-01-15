defmodule Chain do
  import BenBen

  # Define our linked list data type with two variants:
  # cons - for list nodes with a value and next pointer
  # null - for end of list
  phrenia List do
    cons(head, recu(tail))
    null()
  end

  # Create a new list from an Elixir list
  def tool(enum) do
    bend val = Enum.reverse(enum) do
      case val do
        [] -> List.null()
        [head | tail] -> List.cons(head, fork(tail))
      end
    end
  end

  # Convert to Elixir list for easier printing/debugging
  def breaker(linked_list) do
    fold linked_list do
      case(cons(head, tail)) ->
        [head | recu(tail)]

      case(null()) ->
        []
    end
  end

  # Map over list elements with a transform function
  def map(list, transform_fn) do
    fold list do
      case(cons(head, tail)) ->
        List.cons(transform_fn.(head), recu(tail))

      case(null()) ->
        List.null()
    end
  end

  # Filter list elements based on predicate
  def filter(list, predicate) do
    fold list do
      case(cons(head, tail)) ->
        if predicate.(head) do
          List.cons(head, recu(tail))
        else
          recu(tail)
        end

      case(null()) ->
        List.null()
    end
  end

  # Reduce list to single value with accumulator
  def reduce(list, initial, reducer_fn) do
    fold list, with: initial do
      case(cons(head, tail)) ->
        {tail_result, new_acc} = recu(tail)
        result = reducer_fn.(head, new_acc)
        {result, result}

      case(null()) ->
        {state, state}
    end
  end

  # Get length of list
  def length(list) do
    fold list do
      case(cons(head, tail)) -> 1 + recu(tail)
      case(null()) -> 0
    end
  end

  # Reverse the list
  def reverse(list) do
    fold list, with: List.null() do
      case(cons(head, tail)) ->
        {_, acc} = recu(tail)
        result = List.cons(head, acc)
        {result, result}

      case(null()) ->
        {state, state}
    end
  end

  # Concatenate two lists
  def concat(list1, list2) do
    fold list1 do
      case(cons(head, tail)) ->
        List.cons(head, recu(tail))

      case(null()) ->
        list2
    end
  end

  # Take first n elements
  def take(list, n) when n > 0 do
    fold list, with: n do
      case(cons(head, tail)) ->
        if state > 0 do
          {tail_result, new_count} = recu(tail)
          {List.cons(head, tail_result), new_count - 1}
        else
          {List.null(), 0}
        end

      case(null()) ->
        {List.null(), state}
    end
  end

  # Drop first n elements
  def drop(list, n) when n > 0 do
    fold list, with: n do
      case(cons(head, tail)) ->
        if state > 0 do
          {result, new_count} = recu(tail)
          {result, new_count - 1}
        else
          {List.cons(head, recu(tail)), 0}
        end

      case(null()) ->
        {List.null(), state}
    end
  end
end
