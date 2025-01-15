defmodule ChainTest do
  use ExUnit.Case
  doctest Chain

  # Helper function to create test data
  defp sample_list do
    Chain.tool(1..5)
  end

  describe "tool/1" do
    test "creates empty list from empty enum" do
      assert Chain.breaker(Chain.tool([])) == []
    end

    test "creates list from range" do
      assert Chain.breaker(Chain.tool(1..3)) == [1, 2, 3]
    end

    test "creates list from arbitrary enum" do
      assert Chain.breaker(Chain.tool(["a", "b", "c"])) == ["a", "b", "c"]
    end
  end

  describe "map/2" do
    test "maps empty list" do
      assert Chain.breaker(Chain.map(Chain.tool([]), &(&1 * 2))) == []
    end

    test "maps list with transform function" do
      list = sample_list()
      result = Chain.map(list, &(&1 * 2))
      assert Chain.breaker(result) == [2, 4, 6, 8, 10]
    end

    test "maps with complex transform" do
      list = Chain.tool(["a", "b", "c"])
      result = Chain.map(list, &String.upcase/1)
      assert Chain.breaker(result) == ["A", "B", "C"]
    end
  end

  describe "filter/2" do
    test "filters empty list" do
      assert Chain.breaker(Chain.filter(Chain.tool([]), &(&1 > 0))) == []
    end

    test "filters even numbers" do
      list = sample_list()
      result = Chain.filter(list, &(rem(&1, 2) == 0))
      assert Chain.breaker(result) == [2, 4]
    end

    test "filters with complex predicate" do
      list = Chain.tool(["a", "b", "aa", "bb", "aaa"])
      result = Chain.filter(list, &(String.length(&1) > 1))
      assert Chain.breaker(result) == ["aa", "bb", "aaa"]
    end
  end

  describe "reduce/3" do
    test "reduces empty list" do
      {result, _} = Chain.reduce(Chain.tool([]), 0, &(&1 + &2))
      assert result == 0
    end

    test "reduces list to sum" do
      list = sample_list()
      {result, _} = Chain.reduce(list, 0, &(&1 + &2))
      assert result == 15
    end

    test "reduces with string concatenation" do
      list = Chain.tool(["a", "b", "c"])
      {result, _} = Chain.reduce(list, "", &(&2 <> &1))
      assert result == "abc"
    end
  end

  describe "length/1" do
    test "length of empty list" do
      assert Chain.length(Chain.tool([])) == 0
    end

    test "length of non-empty list" do
      assert Chain.length(sample_list()) == 5
    end
  end

  describe "reverse/1" do
    test "reverses empty list" do
      {result, _} = Chain.reverse(Chain.tool([]))
      assert Chain.breaker(result) == []
    end

    test "reverses non-empty list" do
      list = sample_list()
      {result, _} = Chain.reverse(list)
      assert Chain.breaker(result) == [5, 4, 3, 2, 1]
    end
  end

  describe "concat/2" do
    test "concatenates empty lists" do
      empty = Chain.tool([])
      assert Chain.breaker(Chain.concat(empty, empty)) == []
    end

    test "concatenates list with empty list" do
      list = sample_list()
      empty = Chain.tool([])
      assert Chain.breaker(Chain.concat(list, empty)) == [1, 2, 3, 4, 5]
      assert Chain.breaker(Chain.concat(empty, list)) == [1, 2, 3, 4, 5]
    end

    test "concatenates two non-empty lists" do
      list1 = Chain.tool([1, 2, 3])
      list2 = Chain.tool([4, 5, 6])
      result = Chain.concat(list1, list2)
      assert Chain.breaker(result) == [1, 2, 3, 4, 5, 6]
    end
  end

  describe "take/2" do
    test "takes from empty list" do
      {result, _} = Chain.take(Chain.tool([]), 3)
      assert Chain.breaker(result) == []
    end

    test "takes less than list length" do
      list = sample_list()
      {result, _} = Chain.take(list, 3)
      assert Chain.breaker(result) == [1, 2, 3]
    end

    test "takes more than list length" do
      list = sample_list()
      {result, _} = Chain.take(list, 10)
      assert Chain.breaker(result) == [1, 2, 3, 4, 5]
    end
  end

  describe "drop/2" do
    test "drops from empty list" do
      {result, _} = Chain.drop(Chain.tool([]), 3)
      assert Chain.breaker(result) == []
    end

    test "drops less than list length" do
      list = sample_list()
      {result, _} = Chain.drop(list, 2)
      assert Chain.breaker(result) == [3, 4, 5]
    end

    test "drops exact list length" do
      list = sample_list()
      {result, _} = Chain.drop(list, 5)
      assert Chain.breaker(result) == []
    end

    test "drops more than list length" do
      list = sample_list()
      {result, _} = Chain.drop(list, 10)
      assert Chain.breaker(result) == []
    end
  end

  describe "breaker/1" do
    test "converts empty list" do
      assert Chain.breaker(Chain.tool([])) == []
    end

    test "converts non-empty list" do
      original = [1, 2, 3, 4, 5]
      list = Chain.tool(original)
      assert Chain.breaker(list) == original
    end

    test "converts after operations" do
      list = sample_list()
      {reversed, _} = Chain.reverse(list)
      doubled = Chain.map(reversed, &(&1 * 2))
      assert Chain.breaker(doubled) == [10, 8, 6, 4, 2]
    end
  end
end
