import BenBen

deftype MyTree do
  Node(val, ~left, ~right)
  Leaf
end

def sum(tree) do
  fold tree do
    case Node(val, left, right) -> val + ~left + ~right
    case Leaf -> 0
  end
end

def create_tree do
  bend val = 0 do
    when val < 10 do
      Node(val, fork(val + 1), fork(val + 1))
    else
      Leaf
    end
  end
end
