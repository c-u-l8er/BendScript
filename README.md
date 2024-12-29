BenBen
========

## Features

### Algebraic Data Types

Define recursive data structures using a declarative syntax:

```elixir
deftype BinaryTree do
  node(val, recu(left), recu(right))  # recu macro indicates recursive fields
  leaf()
end
```

### Fold Operations

Traverse and transform recursive structures with pattern matching:

```elixir
fold tree do
  case node(val, left, right) -> val + recu(left) + recu(right)
  case leaf() -> 0
end
```

It should properly expand to something like:

```elixir
do_fold(tree, nil, fn value, state ->
  case value do
    %{variant: :node, val: val, left: left, right: right} ->
      val + do_fold(left, nil, value) + do_fold(right, nil, value)
    %{variant: :leaf} ->
      0
  end
end)
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

And it also supports nested bends with different variable names:

```elixir
bend i = 0 do
  bend j = 0 do
    i + j
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

## AI Prompt Notes
ai should:
- keep/add logging
- return only what needs to be updated
