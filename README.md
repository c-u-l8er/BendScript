BenBen
========

## Features

### Algebraic Data Types

Define recursive data structures using a declarative syntax:

```elixir
deftype BinaryTree do
  node(val, @left, @right)  # @ marks recursive fields
  leaf()
end
```

### Fold Operations

Traverse and transform recursive structures with pattern matching:

```elixir
fold tree do
  case node(val, left, right) -> val + @left + @right
  case leaf() -> 0
end
```

### Bend Operations

Create recursive structures using a declarative approach:

```elixir
bend val = 0 do
  if val < 3 do
    BinaryTree.node(val, fork(val + 1), fork(val + 1))
  else
    BinaryTree.leaf()
  end
end
```

## Early setup
```bash
mix new ben_ben
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `benben` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ben_ben, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/benben>.

## Run
```bash
# test project
mix test 2>&1 | tee test.stdout.txt
```
