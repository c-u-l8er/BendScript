defmodule RaRa.Application do
  use Application
  require Logger

  def start(_type, _args) do
    Logger.debug("Starting RaRa.Application")

    children = [
      # Start Registry first
      {Registry, keys: :unique, name: RaRa.Registry, partitions: System.schedulers_online()},
      # Then start the DynamicSupervisor
      {RaRa.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: RaRa.ApplicationSupervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.debug("RaRa.Application started successfully")
        {:ok, pid}

      error ->
        Logger.error("Failed to start RaRa.Application: #{inspect(error)}")
        error
    end
  end
end
