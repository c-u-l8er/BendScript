defmodule SpaceshipQueriesTest do
  use ExUnit.Case
  doctest SpaceshipQueries

  setup do
    # Start registry for distributed nodes
    {:ok, _} = Registry.start_link(keys: :unique, name: DistGraphDatabase.Registry)

    # Start three nodes
    {:ok, node1} = DistGraphDatabase.start_link(:node1)
    {:ok, node2} = DistGraphDatabase.start_link(:node2)
    {:ok, node3} = DistGraphDatabase.start_link(:node3)

    # Join nodes into cluster
    :ok = DistGraphDatabase.join_cluster(:node2, :node1)
    :ok = DistGraphDatabase.join_cluster(:node3, :node1)

    # Wait for leader election
    Process.sleep(500)

    # Define schema for spaceships
    {:ok, tx_id} = DistGraphDatabase.begin_transaction(:node1)

    {:ok, _} =
      DistGraphDatabase.define_schema(:node1, tx_id, :Spaceship,
        name: [type: :string, required: true],
        class: [type: :string, required: false],
        crew_capacity: [type: :integer, required: false]
      )

    {:ok, _} = DistGraphDatabase.commit_transaction(:node1, tx_id)

    {:ok, node: :node1}
  end

  describe "SpaceshipQueries" do
    test "creates and retrieves spaceships", %{node: node} do
      # Create test spaceships
      ships = [
        "Millennium Falcon",
        "X-Wing",
        "Star Destroyer"
      ]

      # Create ships
      created_ships =
        Enum.map(ships, fn name ->
          query = SpaceshipQueries.create_spaceship(name)
          {:ok, ship_id} = CypherExecutor.execute(query, node)
          ship_id
        end)

      # Query all spaceships
      query = SpaceshipQueries.get_all_spaceships()
      {:ok, results} = CypherExecutor.execute(query, node)

      # Verify results
      assert length(results) == length(ships)

      ship_names = Enum.map(results, & &1.properties.name)
      assert Enum.all?(ships, &(&1 in ship_names))
    end

    test "creates spaceship with properties", %{node: node} do
      # Create spaceship with additional properties
      query =
        SpaceshipQueries.create_spaceship_with_details(%{
          name: "Enterprise",
          class: "Constitution",
          crew_capacity: 430
        })

      {:ok, ship_id} = CypherExecutor.execute(query, node)

      # Query specific spaceship
      query = SpaceshipQueries.get_spaceship_by_name("Enterprise")
      {:ok, [ship]} = CypherExecutor.execute(query, node)

      # Verify properties
      assert ship.properties.name == "Enterprise"
      assert ship.properties.class == "Constitution"
      assert ship.properties.crew_capacity == 430
    end

    test "handles empty results", %{node: node} do
      # Query before creating any spaceships
      query = SpaceshipQueries.get_all_spaceships()
      {:ok, results} = CypherExecutor.execute(query, node)

      assert results == []
    end

    test "filters spaceships by class", %{node: node} do
      # Create spaceships of different classes
      ships = [
        %{name: "X-Wing 1", class: "Starfighter"},
        %{name: "X-Wing 2", class: "Starfighter"},
        %{name: "Star Destroyer", class: "Capital"}
      ]

      # Create all ships
      Enum.each(ships, fn ship ->
        query = SpaceshipQueries.create_spaceship_with_details(ship)
        {:ok, _} = CypherExecutor.execute(query, node)
      end)

      # Query starfighters
      query = SpaceshipQueries.get_spaceships_by_class("Starfighter")
      {:ok, results} = CypherExecutor.execute(query, node)

      assert length(results) == 2
      assert Enum.all?(results, &(&1.properties.class == "Starfighter"))
    end
  end
end
