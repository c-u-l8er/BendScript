defmodule MyTree do
  import BenBen

  deftype MyTree do
    node(val, recu(left), recu(right))
    leaf()
  end

  def sum(tree) do
    fold tree do
      case(node(val, left, right)) -> val + recu(left) + recu(right)
      case(leaf()) -> 0
    end
  end

  def create_tree do
    bend val = 0 do
      if val < 10 do
        MyTree.node(val, fork(val + 1), fork(val + 1))
      else
        MyTree.leaf()
      end
    end
  end
end
