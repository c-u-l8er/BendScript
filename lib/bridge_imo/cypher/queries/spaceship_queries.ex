defmodule SpaceshipQueries do
  require Logger
  import ExCypher

  def get_all_spaceships do
    Logger.debug("Building get_all_spaceships query")

    cypher do
      match(node(:s, [:Spaceship]))
      return(:s)
    end
  end

  def create_spaceship(name) do
    Logger.debug("Building create_spaceship query for name: #{inspect(name)}")

    cypher do
      create(node(:s, [:Spaceship], %{name: name}))
      return(:s)
    end
  end

  def create_spaceship_with_details(properties) do
    Logger.debug("Building create_spaceship_with_details query")
    Logger.debug("Properties: #{inspect(properties)}")

    cypher do
      create(node(:s, [:Spaceship], properties))
      return(:s)
    end
  end

  def get_spaceship_by_name(name) do
    Logger.debug("Building get_spaceship_by_name query for: #{inspect(name)}")

    cypher do
      match(node(:s, [:Spaceship]))
      where(s.name == name)
      return(:s)
    end
  end

  def get_spaceships_by_class(class) do
    Logger.debug("Building get_spaceships_by_class query for: #{inspect(class)}")

    cypher do
      match(node(:s, [:Spaceship]))
      where(s.class == class)
      return(:s)
    end
  end
end
