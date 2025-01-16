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
  def tool(enum) when is_list(enum) do
    bend val = enum do
      case val do
        [] -> List.null()
        [head | tail] -> List.cons(head, fork(tail))
      end
    end
  end

  def tool(enum) do
    # Handle any other enumerable by converting to list first
    enum
    |> Enum.to_list()
    |> tool()
  end

  # Convert to Elixir list for easier printing/debugging
  def breaker(linked_list) do
    result =
      case linked_list do
        # Handle fork tuples from bend
        {:fork, list} ->
          breaker(list)

        # Handle state tuples from fold/reverse operations
        {list, _state} ->
          # Process the actual list part from the tuple
          fold list do
            case(cons(head, tail)) -> [head | recu(tail)]
            case(null()) -> []
          end

        # Process actual list structure
        list ->
          fold list do
            case(cons(head, tail)) ->
              [head | recu(tail)]

            case(null()) ->
              []
          end
      end

    # Ensure we handle both direct lists and tupled results
    case result do
      {list, _state} when is_list(list) -> list
      list when is_list(list) -> list
      other -> raise "Unexpected result: #{inspect(other)}"
    end
  end

  # Map over list elements with a transform function
  def map(list, transform_fn) do
    result =
      fold list do
        case(cons(head, tail)) ->
          List.cons(transform_fn.(head), recu(tail))

        case(null()) ->
          List.null()
      end

    {result, nil}
  end

  # Filter list elements based on predicate
  def filter(list, predicate) do
    result =
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

    {result, nil}
  end

  def reverse(list) do
    {do_reverse(list, List.null()), nil}
  end

  # Helper function to do the actual recursion
  defp do_reverse(list, acc) do
    case list do
      %{variant: :cons, head: head, tail: tail} ->
        # Take head and prepend to accumulator
        do_reverse(tail, List.cons(head, acc))

      %{variant: :null} ->
        # Return accumulated reversed list
        acc
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
    # Initialize and track state through bend's value
    result =
      bend val = {list, List.null()} do
        case elem(val, 0) do
          %{variant: :cons, head: head, tail: tail} ->
            # First create our new list node with current head
            List.cons(
              head,
              case fork(tail) do
                # Handle recursive result
                %{variant: :cons} = next -> next
                %{variant: :null} -> List.null()
                # Handle initial processing
                {:fork, next} -> next
              end
            )

          %{variant: :null} ->
            # At end of list, return the accumulated reversed list
            elem(val, 1)
        end
      end

    # The result is already in reversed order, no need to reverse again
    {result, result}
  end

  # Concatenate two lists
  def concat(list1, list2) do
    result =
      fold list1 do
        case(cons(head, tail)) ->
          List.cons(head, recu(tail))

        case(null()) ->
          list2
      end

    {result, nil}
  end

  # Reduce implementation
  def reduce(list, initial, fun) do
    fold list, with: initial do
      case(cons(head, tail)) ->
        # Get the recursive result first
        {_tail_result, acc} = recu(tail)
        # Apply function to accumulator and current head
        # Changed order here
        {List.null(), fun.(acc, head)}

      case(null()) ->
        # Return initial value for empty list
        {List.null(), state}
    end
    |> case do
      {_list, acc} -> {acc, nil}
    end
  end

  # Take first n elements
  def take(list, n) when n > 0 do
    result =
      bend val = {list, n} do
        case elem(val, 0) do
          %{variant: :cons, head: head, tail: tail} ->
            count = elem(val, 1)

            if count > 0 do
              List.cons(head, fork({tail, count - 1}))
            else
              List.null()
            end

          %{variant: :null} ->
            List.null()
        end
      end

    {result, nil}
  end

  # Drop first n elements
  def drop(list, n) when n > 0 do
    {do_drop(list, n), nil}
  end

  defp do_drop(%{variant: :cons, head: _head, tail: tail}, n) when n > 0 do
    do_drop(tail, n - 1)
  end

  defp do_drop(%{variant: :null}, _n) do
    List.null()
  end

  # Once we've dropped n elements, return the rest of the list
  defp do_drop(list, 0) do
    list
  end
end
