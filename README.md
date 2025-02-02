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

now:
exploration by both detection and discovery
is the goal

where:
compsci is just a means to an end
and gr is our field+trait

so let's get started!

best,
~Travis
```

the splitting and merging phrenia:
```elixir
# benben includes phrenia, bend, fold, fork, and recu marcos
# where recu indicates recursive fields
import KernelShtf.BenBen

# here is a type of brain that can be defined
phrenia BinaryTree do
  node(val, recu(left), recu(right))
  leaf()
end

# other types of brains such as linked lists are possible
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

# this one is without weights or properties
phrenia SimpleGraph do
  graph(vertices, recu(edges))
  edge(from, to)
  empty()
end

# here is an example without recursion
phrenia Transaction do
  pending(operations, timestamp)
  committed(changes, timestamp)
  rolled_back(reason, timestamp)
end
```

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
- bend -> which is about recusive splitting and allocation using conditions
- fold -> which is about recusive merging and computation using cases

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

- the first is, "DeJa: Video Ultra"
- the second is, "Thread & Burl"

i wont be registering official domain names for them to save money
instead i'll just create seperate github repos and link to this
main repo when i need to.

everything in graphrenia will act as a singleton. i only have a one
old xeon machine connected to the internet that will run BEAM.

when i need more machines i will just add them as soon as i can
afford them but soon i'm hoping to save $200 a month for a couple
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
run any kind of home setup up until i reach 5Gbps max speed connection
but i am currently paying $60 month for 500Mbps.

besides a brain for a data structure the next most and equally important
thing is memory and the ability to think or "wonder" about on that
said memory.

```elixir
use KernelShtf.Wonder

# Define initial state
magic do
  %{count: 0}
end

# Define synchronous calls
force(:increment, [amount]) do
  new_count = state.count + amount
  %{state | count: new_count}
end

# Define asynchronous casts
spell(:reset, []) do
  %{state | count: 0}
end
```

the above is basically an elixir generic server with syntax that
will make you feel like a wizard with a wond when you code in it.

in the above example state and magic mean the same thing and it
can be used as memory for your phrenia recu data types. more on
this later.

so far we have seen 2 modules from KernelShtf that are a key part
to what we are about to layer on top next which is abstract and
concrete concepts and the ability to bridge between the two. we
are also going to add domain driven design struct on top of that which
looks something like the following in layers.

```elixir
# layer 0 (system)
import KernelShtf

# layer 1.A (mental)
import AbstractPov

# layer 1.B (physical)
import ConcreteIrl

# layer 2 (mind-body connection)
import BridgeImo

# layer 3 (core)
import XyzCore

# layer 3.X (applications)
import XyzApps.Api
import XyzApps.Web
```
> checkout `./lib` for the full source code.

```bash
# READ!!! sotries for a coninuation of this documentation :)
cat ./storeis/STORY1.md
cat ./storeis/STORY2.md
cat ./storeis/STORY3.md
```

> note: story driven design seams like a great way to get the compsci juices flowing. the above stories are great but i still have some concepts that i'd like to further develop like better characters.

*(hand is to glove as foot is to sock)*

Are "is to" statemnets more harmful than "go to" statements?

The "is to" -> Analogy Statement Table (AST):

| kind | field+trait | attack | strength | defense |
|------|-------------|--------|----------|---------|
| rabbit | electromagnetism | short | strong | distributed |
| lion | gravity | long | weak | centralized |
| dragon | magic | medium | medium | balanced |

```bash
# READ!!! where we unravel the above "is to" AST's mystories
cat ./resonance_patterns/INTRO.md
cat ./resonance_patterns/SYSTEM_UNDER_STRESS.md
cat ./resonance_patterns/EMERGENT_EVOLUTION.md
```

in the above pantheon we got 3 main characters:
- Echo
- Nexus
- Harmony

let's call them the founders of our LEAGUE who are going to detect and
discover RACE. as they work together they will build RACE from scratch
starting from themselves, the knowledge that they gained from
their own "is to" -> Analogy Statement Table, and their
combined resonance patterns.

so far we have intro/structured BenBen and Wonder...

the above intro/structures AST pantheons called LEAGUES...

now we are going to intro/structure stage-based
workflows aka checkpoint-based tracks called RACE...

in Elixir this is known as GenStage, Flow, and Broadway however
we are going to simplify and codify a better solution using macros.

here is how to define a track aka "pipeline"
with checkpoints aka "producers"
```elixir
use KernelShtf.Race

track TestTrack do
  checkpoints(
    module: DummyJumper,
    checker_concurrency: 2,
    batch_size: 50
  )
end
```

quantifying abstract terminology:
- producer -> jumper
- consumer -> lander
- processor -> checker

let's define "DummyJumper" that was stated in our checkpoints module...
```elixir
defmodule TestMessage do
  defstruct [:data]
end

defmodule DummyJumper do
  use GenStage

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(counter: counter) do
    {:jumper, counter}
  end

  def handle_demand(demand, counter) when demand > 0 do
    events = Enum.map(counter..(counter + demand - 1), &%TestMessage{data: &1})
    {:noreply, events, counter + demand}
  end
end
```

here is the MAP checkpoints (jumps and landings)...
```elixir
jump TestJump do
  def handle_demand(demand, state) do
    events = Enum.to_list(1..demand)
    {:noreply, events, state}
  end
end

land TestLand, [TestJump] do
  def handle_events(events, _from, state) do
    send(state.test_pid, {:events_received, events})
    {:noreply, [], state}
  end
end
```

here is how we can test this MAP and it's checkpoints...
```elixir
describe "jump and land" do
  test "producer-consumer communication" do
    {:ok, jumper} = TestJump.start_link([])
    {:ok, lander} = TestLand.start_link(%{test_pid: self()})

    # Wait for events
    assert_receive {:events_received, events}, 1000
    assert length(events) > 0
    assert Enum.all?(events, &is_integer/1)
  end
end
```

In Elixir, **GenStage**, **Flow**, and **Broadway** are tools for working with concurrent, parallel, and distributed data processing. Here's a comparison chart:
| Feature             | GenStage                | Flow                   | Broadway                  |
|---------------------|-------------------------|------------------------|---------------------------|
| Abstraction Level   | Low-level primitives    | Higher-level abstraction | High-level, production-ready framework |
| Focus               | Producer-consumer stages | Data transformation   | External system integrations |
| Built-in Adapters   | No                      | No                     | Yes (e.g., SQS, RabbitMQ) |
| Use Cases           | Custom workflows        | Parallel data processing | Scalable data pipelines   |

conclusion:
- Use **GenStage** if you need fine-grained control over stage-based workflows.
- Use **Flow** for parallel data processing and stream transformations.
- Use **Broadway** for building robust, production-ready pipelines that integrate with external systems.

reflection:
now that we have BenBen, Wonder, and Race kernel modules as well as three 10x developers (Echo, Nexus, and Harmony)
let's see if we now generate better stories that have more solid foundation of our core values.

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
mix test 2>&1 | tee test.stdout.txt

# test specific files
mix test test/abc_law/vending_machine_test.exs 2>&1 | tee vending_machine_test.stdout.txt

mix test test/kernel_shtf/race_test.exs 2>&1 | tee kernel_shft_race.stdout.txt

mix test test/concrete_irl/graffiti_test.exs 2>&1 | tee concrete_irl_graffiti.stdout.txt

mix test test/abstract_pov/counter_test.exs 2>&1 | tee abstract_pov_counter.stdout.txt
mix test test/abstract_pov/chain_test.exs 2>&1 | tee abstract_pov_chain.stdout.txt
mix test test/abstract_pov/parents_test.exs 2>&1 | tee abstract_pov_parents.stdout.txt
mix test test/abstract_pov/prop_graph_test.exs 2>&1 | tee abstract_pov_prop_graph.stdout.txt
mix test test/abstract_pov/simple_graph_test.exs 2>&1 | tee abstract_pov_simple_graph.stdout.txt

# test specific tests within a file
mix test test/abstract_pov/chain_test.exs --only run:true 2>&1 | tee abstract_pov_chain.stdout.txt
```

## AI Prompt Notes
ai should:
- keep/add logging
- return only what needs to be updated
- when filling out case arguements for fold you cant use _ you must use the full variant name
- within bend and fold variable arguments must match the phrenia variable definitions
