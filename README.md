graphrenia
========
main domain:
```text
just one field to rule all other fields
as -phic and -vity as gra- itself

graphrenia:
gr -> to program
a -> one
phrenia -> brain

coded by a schizo in check with meds
maintained for fun

my learned hardships are your learned gains
background in php -> javascript -> node.js -> elixir
with programming exp starting at 15 years old

20+ years later... many challenges later...
all self hosted & local at home... because
i can't afford the cloud on disability
worst retirement ever :)

now,
exploration and discovery is the goal
where compsci is just a means to an end
and gr is that playing field

so let's get started!

best,
~Travis
```

the splitting and merging phrenia:
```elixir
# benben includes phrenia, bend, fold, fork, and recu marcos
# where recu indicates recursive fields
import BenBen

# here is a type of brain that can be defined
phrenia BinaryTree do
  node(val, recu(left), recu(right))
  leaf()
end

# other types of brains such as lists are possible
phrenia List do
  cons(head, recu(tail))
  null()
end

# as well as property graphs
phrenia PropGraph do
  graph(vertex_map, recu(edge_list), metadata)
  vertex(vertex_id, properties, recu(adjacency))
  edge(source_id, target_id, edge_weight, edge_props)
  empty()
end

# here is an example without recursion
phrenia Transaction do
  pending(operations, timestamp)
  committed(changes, timestamp)
  rolled_back(reason, timestamp)
end
```
> full examples are in ./lib/examples

what is a BenBen tho?
```text
a Benben is the only unique stone on a pyramid
that also happens to be the shape of a pyramid
and sits at the top dating back to ancient egypt.

it has similar magic to recursion because it is
also a repeated pattern with in a structure; as in
their shapes reoccur in a pattern when looping
over said struct similarly in style.

i also really like pyramids too.
i also really like 1 + 1 philosophy.
so BenBen it is!
```

when it comes to looping over the phrenia data type...

we have two methods:
bend -> which is about recusive splitting and allocation using conditions
fold -> which is about recusive merging and computation using cases

first, let's have a look at bend...
```elixir
# Create recursive structures using a declarative approach:
bend val = 0 do
  if val < 3 do
    BinaryTree.node(val, fork(val + 1), fork(val + 1))
  else
    BinaryTree.leaf()
  end
end

# And it also supports nested bends with different variable names:
bend i = 0 do
  bend j = 0 do
    i + j
  end
end
```

second, let's have a look at fold...
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

# It should properly expand to something like:
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

as you can tell bend and fold are two powerful ways,
along with phrenia, of defining/working-with any type of recursive
data structure.

i got their inspiration from bendlang by Higher Order Co
they also happen to be implemented in the Haskel programming language.

now, i am still new to Elixir but i am hoping to change that with a
couple of projects. the main goal is still compsci but i'd like to
fit in at least 2 big projects as stepping stones that will hopefully
get me there.

the first is, "DeJa: Video Ultra"
the second is, "Thread & Burl"

i wont be registering official domain names for them to save money
instead i'll just create seperate github repos and link to this
main repo when i need to.

everything in graphrenia will act as a singleton. i only have a one
old xeon machine connected to the internet that will run BEAM.

when i need more machines i will just add them as soon as i can
afford them but soon i'm hoping to save $250 a month for a couple
of mini pcs or even try getting one of those new Ryzen 16 core CPUs.

when i say act as a singleton i mean when i add more machines they
will all see each other and there will be no test or staging cluster only
a single production cluster. all BEAM nodes.

so rather than using kubernetes i will have to figure out how to
run multiple instances of the same application as well as different
applications all on a single BEAM instance/cluster.

when i happen to find a lot of money i will use these machines as
a test or staging and then use the cloud or find a nearby
datacenter and colocate :)

the plus side is that i have a fiber connection at home and can
run any kind of business up until i reach 5Gbps max speed connection
but i am currently paying $60 month for 500Mbps.


## Early setup
```bash
mix new graphrenia
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `graphrenia` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:graphrenia, "~> 0.1.0"}
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
mix test test/examples/counter_test.exs 2>&1 | tee counter.stdout.txt
mix test test/examples/chain_test.exs 2>&1 | tee chain.stdout.txt
mix test test/examples/graffiti_test.exs 2>&1 | tee graffiti.stdout.txt
mix test test/examples/parents_test.exs 2>&1 | tee parents.stdout.txt
mix test test/examples/prop_graph_test.exs 2>&1 | tee prop_graph.stdout.txt
```

## AI Prompt Notes
ai should:
- keep/add logging
- return only what needs to be updated
- when filling out case arguements for fold you cant use _ you must use the full variant name
- within bend and fold variable arguments must match the phrenia variable definitions
