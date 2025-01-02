defmodule Mix.Tasks.Test.Distributed do
  use Mix.Task

  @shortdoc "Runs tests in distributed mode"
  def run(args) do
    node_name = "test_node@127.0.0.1"

    System.cmd(
      "elixir",
      ["--name", node_name, "-S", "mix", "test" | args],
      into: IO.stream(:stdio, :line)
    )
  end
end
