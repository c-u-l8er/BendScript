BenBen
========

## Features

### Algebraic Data Types

Define recursive data structures using a declarative syntax:

```elixir
deftype BinaryTree do
  node(val, recu(left), recu(right))  # recu indicates recursive fields
  leaf()
end
```

### Fold Operations

Traverse and transform recursive structures with pattern matching:

```elixir
# Stateless operation
sum = fold tree do
  case node(val, left, right) -> val + recu(left) + recu(right)
  case leaf() -> 0
end

# Stateful operation
{result, final_state} = fold list, with: 0 do
  case cons(head, tail) ->
    {tail_value, new_state} = recu(tail)
    new_sum = head + tail_value
    {head, new_sum}
  case null() -> {0, state}
end
```

It should properly expand to something like:

```elixir
do_fold(list, 0, fn value, state ->
  case value do
    %{variant: :cons, head: head, tail: tail} ->
      result = head + (
        {tail_result, new_state} = do_fold(tail, state, value)
        state = new_state
        tail_result
      )
      {result, state}
    %{variant: :null} ->
      {0, state}
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
# test everything
mix test 2>&1 | tee test.sdtout.txt

# test reg server
mix test test/examples/reg_server_test.exs 2>&1 | tee reg_server.stdout.txt

```

## AI Prompt Notes
ai should:
- keep/add logging
- return only what needs to be updated
- when filling out case arguements for fold you cant use _ you must use the full variant name
- within bend and fold variable arguments must match the deftype variable definitions
