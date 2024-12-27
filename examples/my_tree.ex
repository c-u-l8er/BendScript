import BenBen

deftype MyTree do
  node(val, @left, @right)
  leaf()
end

def sum(tree) do
  fold tree do
    case(node(val, left, right)) -> val + @left + @right
    case(leaf()) -> 0
  end
end

def create_tree do
  bend val = 0 do
    if val < 10 do
      node(val, fork(val + 1), fork(val + 1))
    else
      leaf()
    end
  end
end
