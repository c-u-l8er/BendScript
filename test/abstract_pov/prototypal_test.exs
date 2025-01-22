defmodule PrototypalTest do
  use ExUnit.Case
  import Prototypal

  test "prototypal inheritance" do
    # Create prototype chain
    person_proto = Prototypal.create_person_prototype()
    employee_proto = Prototypal.create_employee_prototype(person_proto)

    # Create specific employee
    john = Prototypal.create_employee("John", "Developer", employee_proto)

    # Basic property access
    assert Prototypal.get_property(john, :name) == "John"
    assert Prototypal.get_property(john, :species) == "human"
    assert Prototypal.get_property(john, :role) == "Developer"

    # Method access
    greet_fn = Prototypal.get_property(john, :greet)
    assert greet_fn.("Alice") == "Hello, Alice!"

    work_fn = Prototypal.get_property(john, :work)
    assert work_fn.() == "Working..."

    # Test property setting
    john2 = Prototypal.set_property(john, :skill, "Elixir")
    assert Prototypal.get_property(john2, :skill) == "Elixir"

    # Verify prototype chain is unaffected
    assert Prototypal.get_property(employee_proto, :skill) == nil
    # Original instance unchanged
    assert Prototypal.get_property(john, :skill) == nil
  end

  test "property chain lookup" do
    # Additional test to verify property chain lookup
    base = Prototypal.create_object(%{a: 1})
    derived = Prototypal.create_object(%{b: 2}, base)
    instance = Prototypal.create_object(%{c: 3}, derived)

    assert Prototypal.get_property(instance, :a) == 1
    assert Prototypal.get_property(instance, :b) == 2
    assert Prototypal.get_property(instance, :c) == 3
    assert Prototypal.get_property(instance, :d) == nil
  end
end
