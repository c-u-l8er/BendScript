defmodule SpaceshipQueries do
  import ExCypher

  def get_all_spaceships do
    cypher do
      match(node(:s, [:Spaceship]))
      return(:s)
    end
  end

  def create_spaceship(name) do
    cypher do
      create(node(:s, [:Spaceship], %{name: name}))
      return(:s)
    end
  end

  def create_spaceship_with_details(properties) do
    cypher do
      create(node(:s, [:Spaceship], properties))
      return(:s)
    end
  end

  def get_spaceship_by_name(name) do
    cypher do
      match(node(:s, [:Spaceship]))
      where("s.name = '#{name}'")
      return(:s)
    end
  end

  def get_spaceships_by_class(class) do
    cypher do
      match(node(:s, [:Spaceship]))
      where("s.class = '#{class}'")
      return(:s)
    end
  end
end
