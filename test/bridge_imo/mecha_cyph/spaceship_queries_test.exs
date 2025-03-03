defmodule SpaceshipQueriesTest do
  use ExUnit.Case
  doctest SpaceshipQueries
  require Logger

  alias Graffiti
  alias SpaceshipQueries
  alias MechaCyph

  setup do
    state = %Graffiti.State{
      graph: PropGraph.new(:directed),
      schema: %{},
      transactions: %{},
      locks: %{},
      transaction_counter: 0
    }

    state =
      Graffiti.define_vertex_type(state, :Spaceship,
        name: [type: :string, required: true],
        class: [type: :string, required: false],
        crew_capacity: [type: :integer, required: false]
      )

    {:ok, state: state}
  end

  describe "SpaceshipQueries" do
    test "creates and retrieves spaceships", %{state: state} do
      ships = ["Millennium Falcon", "X-Wing", "Star Destroyer"]
      {:ok, mecha_cyph_pid} = MechaCyph.start_link([])

      new_state =
        Enum.reduce(ships, state, fn name, acc_state ->
          query_data = SpaceshipQueries.create_spaceship(mecha_cyph_pid, name)
          # IO.inspect(query_data, label: "Create Spaceship Query")
          # state = MechaCyph.execute_query(mecha_cyph_pid,query_data)

          # {:ok, updated_graph} = MechaCyph.execute_query(mecha_cyph_pid, acc_state)
          # updated_graph
          {:ok, updated_graph} =
            case SpaceshipQueries.create_spaceship(mecha_cyph_pid, name) do
              query_map ->
                case MechaCyph.execute_query(mecha_cyph_pid, acc_state) do
                  {:ok, new_state} -> {:ok, new_state}
                  {:error, reason} -> {:error, reason}
                end

              {:error, reason} ->
                {:error, reason}
            end
        end)

      IO.inspect(new_state)

      # Query back created ships
      final_data = SpaceshipQueries.get_all_spaceships(mecha_cyph_pid)
    end

    @tag :skip
    test "creates spaceship with properties", %{state: state} do
      properties = %{
        name: "Enterprise",
        class: "Constitution",
        crew_capacity: 430
      }
    end

    @tag :skip
    test "handles empty results", %{state: state} do
    end

    @tag :skip
    test "filters spaceships by class", %{state: state} do
      ships = [
        %{name: "X-Wing 1", class: "Starfighter"},
        %{name: "X-Wing 2", class: "Starfighter"},
        %{name: "Star Destroyer", class: "Capital"}
      ]
    end
  end
end
