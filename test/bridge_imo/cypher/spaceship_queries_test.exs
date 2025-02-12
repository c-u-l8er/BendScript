defmodule SpaceshipQueriesTest do
  use ExUnit.Case
  doctest SpaceshipQueries
  require Logger

  alias Graffiti
  alias CypherExecutor

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
    # @tag :skip
    test "creates and retrieves spaceships", %{state: state} do
      ships = ["Millennium Falcon", "X-Wing", "Star Destroyer"]

      {new_state, _errors} =
        Enum.reduce(ships, {state, []}, fn name, {acc_state, acc_errors} ->
          query = SpaceshipQueries.create_spaceship(name)
          Logger.debug("Generated create query string: #{inspect(query)}")

          case CypherExecutor.execute(query, acc_state) do
            {:ok, {[{vertex_id, _, _}], new_state}} ->
              # Verify vertex was created with correct properties
              vertex = Map.get(new_state.graph.vertex_map, vertex_id)

              if vertex.properties.name == name do
                {new_state, acc_errors}
              else
                {acc_state, ["Vertex properties mismatch" | acc_errors]}
              end

            {:error, reason} ->
              Logger.error("Error creating spaceship: #{reason}")
              {acc_state, [reason | acc_errors]}
          end
        end)

      # Query back created ships
      query = SpaceshipQueries.get_all_spaceships()
      Logger.debug("Executing query: #{query}")

      case CypherExecutor.execute(query, new_state) do
        {:ok, {results, _}} ->
          ship_names =
            Enum.map(results, fn {vertex_id, _, _} ->
              vertex = Map.get(new_state.graph.vertex_map, vertex_id)
              vertex.properties.name
            end)

          assert length(results) == length(ships)
          assert Enum.all?(ships, &(&1 in ship_names))

        {:error, reason} ->
          flunk("Error retrieving spaceships: #{reason}")
      end
    end

    @tag :skip
    test "creates spaceship with properties", %{state: state} do
      properties = %{
        name: "Enterprise",
        class: "Constitution",
        crew_capacity: 430
      }

      query = SpaceshipQueries.create_spaceship_with_details(properties)
      Logger.debug("Executing query: #{query}")

      case CypherExecutor.execute(query, state) do
        {:ok, {_, new_state}} ->
          # Query back the created ship
          query = SpaceshipQueries.get_spaceship_by_name("Enterprise")

          case CypherExecutor.execute(query, new_state) do
            {:ok, {[{vertex_id, _, _}], _}} ->
              vertex = Map.get(new_state.graph.vertex_map, vertex_id)
              assert vertex.properties.name == "Enterprise"
              assert vertex.properties.class == "Constitution"
              assert vertex.properties.crew_capacity == 430

            {:error, reason} ->
              flunk("Error retrieving spaceship: #{reason}")
          end

        {:error, reason} ->
          flunk("Error creating spaceship: #{reason}")
      end
    end

    @tag :skip
    test "handles empty results", %{state: state} do
      query = SpaceshipQueries.get_all_spaceships()
      Logger.debug("Executing query: #{query}")

      case CypherExecutor.execute(query, state) do
        {:ok, {results, _}} ->
          assert results == []

        {:error, reason} ->
          flunk("Error executing query: #{reason}")
      end
    end

    @tag :skip
    test "filters spaceships by class", %{state: state} do
      ships = [
        %{name: "X-Wing 1", class: "Starfighter"},
        %{name: "X-Wing 2", class: "Starfighter"},
        %{name: "Star Destroyer", class: "Capital"}
      ]

      {new_state, _errors} =
        Enum.reduce(ships, {state, []}, fn ship, {acc_state, acc_errors} ->
          query = SpaceshipQueries.create_spaceship_with_details(ship)
          Logger.debug("Executing create query: #{query}")

          case CypherExecutor.execute(query, acc_state) do
            {:ok, {_, new_state}} ->
              {new_state, acc_errors}

            {:error, reason} ->
              Logger.error("Error creating spaceship: #{reason}")
              {acc_state, [reason | acc_errors]}
          end
        end)

      query = SpaceshipQueries.get_spaceships_by_class("Starfighter")
      Logger.debug("Executing query: #{query}")

      case CypherExecutor.execute(query, new_state) do
        {:ok, {results, _}} ->
          assert length(results) == 2

          all_starfighters =
            Enum.all?(results, fn {vertex_id, _, _} ->
              vertex = Map.get(new_state.graph.vertex_map, vertex_id)
              vertex.properties.class == "Starfighter"
            end)

          assert all_starfighters

        {:error, reason} ->
          flunk("Error filtering spaceships: #{reason}")
      end
    end
  end
end
