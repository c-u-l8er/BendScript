defmodule RaRa.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: RaRa.Registry},
      {RaRa.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: RaRa.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
