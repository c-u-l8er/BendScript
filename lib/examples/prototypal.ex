defmodule Prototypal do
  import BenBen

  # Define the object type structure
  phrenia ProtoObject do
    # Object with properties and prototype chain
    object(props, recu(proto))
    # End of prototype chain
    null()
  end

  # Create a new object with given properties and prototype
  def create_object(props, proto \\ ProtoObject.null()) do
    ProtoObject.object(props, proto)
  end

  # Get a property, traversing the prototype chain
  def get_property(obj, key) do
    fold obj do
      case(object(props, proto)) ->
        case Map.get(props, key) do
          # Not found, check prototype
          nil -> recu(proto)
          # Found in current object
          val -> val
        end

      case(null()) ->
        # Property not found in entire chain
        nil
    end
  end

  # Set a property on the object (doesn't affect prototype)
  def set_property(%{variant: :object, props: props, proto: proto} = _obj, key, value) do
    # Create new object with updated properties
    ProtoObject.object(
      Map.put(props, key, value),
      proto
    )
  end

  # Example of creating prototype-based inheritance
  def create_person_prototype() do
    create_object(%{
      greet: fn name -> "Hello, #{name}!" end,
      species: "human"
    })
  end

  def create_employee_prototype(person_proto) do
    create_object(
      %{
        work: fn -> "Working..." end,
        role: "employee"
      },
      person_proto
    )
  end

  # Create a specific instance
  def create_employee(name, role, proto) do
    create_object(
      %{
        name: name,
        role: role
      },
      proto
    )
  end

  def inspect_object(obj, level \\ 0) do
    fold obj do
      case(object(props, proto)) ->
        indent = String.duplicate("  ", level)
        IO.puts("#{indent}Properties: #{inspect(props)}")
        IO.puts("#{indent}Proto:")
        recu(proto)

      case(null()) ->
        indent = String.duplicate("  ", level)
        IO.puts("#{indent}[End of chain]")
    end
  end

  def debug_chain(obj, key) do
    fold obj do
      case(object(props, proto)) ->
        case Map.get(props, key) do
          nil ->
            IO.puts("Not found in #{inspect(props)}, checking prototype")
            recu(proto)

          val ->
            IO.puts("Found #{key}: #{inspect(val)} in #{inspect(props)}")
            val
        end

      case(null()) ->
        IO.puts("Reached end of prototype chain")
        nil
    end
  end
end
