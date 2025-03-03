defmodule SpaceshipQueries do
  require Logger
  import BridgeImo.MechaCyph.ExecBattle
  alias Graffiti
  alias PropGraph
  alias BridgeImo.MechaCyph.QueryBuilder

  def get_all_spaceships(mcid) do
    Logger.debug("Building get_all_spaceships query")

    cyph mecha: mcid do
      match(node(:s, [:Spaceship], %{}))
      return(:s)
    end
  end

  def create_spaceship(mcid, name) do
    Logger.debug("Building create_spaceship query for name: #{inspect(name)}")

    cyph mecha: mcid do
      create(node(:s, [:Spaceship], %{name: name}))
      return(:s)
    end
  end

  def create_spaceship_with_details(mcid, properties) do
    Logger.debug("Building create_spaceship_with_details query")
    Logger.debug("Properties: #{inspect(properties)}")

    cyph mecha: mcid do
      create(node(:s, [:Spaceship], properties))
      return(:s)
    end
  end

  def get_spaceship_by_name(mcid, name) do
    Logger.debug("Building get_spaceship_by_name query for: #{inspect(name)}")

    cyph mecha: mcid do
      match(node(s = :s, [:Spaceship], %{}))
      where(s.properties[:name] == name)
      return(:s)
    end
  end

  def get_spaceships_by_class(mcid, class) do
    Logger.debug("Building get_spaceships_by_class query for: #{inspect(class)}")

    cyph mecha: mcid do
      match(node(s = :s, [:Spaceship], %{}))
      where(s.properties[:class] == class)
      return(:s)
    end
  end
end
