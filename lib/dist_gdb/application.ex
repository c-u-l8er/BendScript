defmodule DistGraphDatabase.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: DistGraphDatabase.Registry}
    ]

    opts = [strategy: :one_for_one, name: DistGraphDatabase.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
