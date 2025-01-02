defmodule RaRa.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      # Child specs for Ra nodes will be added dynamically
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_node(config) do
    child_spec = %{
      id: config.node_id,
      start: {RaRa, :start_link, [config]},
      restart: :permanent,
      type: :worker
    }

    Supervisor.start_child(__MODULE__, child_spec)
  end
end
