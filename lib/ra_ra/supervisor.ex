defmodule RaRa.Supervisor do
  # Change to DynamicSupervisor
  use DynamicSupervisor
  require Logger

  def start_link(opts) do
    Logger.debug("Starting RaRa.Supervisor")
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.debug("Initializing RaRa.Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_node(config) do
    Logger.debug("Starting node #{inspect(config.node_id)}")

    child_spec = %{
      id: config.node_id,
      start: {RaRa, :start_link, [config]},
      restart: :permanent,
      type: :worker
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.debug("Started node #{inspect(config.node_id)} with pid #{inspect(pid)}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.debug("Node #{inspect(config.node_id)} already started with pid #{inspect(pid)}")
        {:ok, pid}

      error ->
        Logger.error("Failed to start node #{inspect(config.node_id)}: #{inspect(error)}")
        error
    end
  end

  def stop_node(node_id) do
    Logger.debug("Stopping node #{inspect(node_id)}")

    case Registry.lookup(RaRa.Registry, node_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        Logger.warn("No process found for node #{inspect(node_id)}")
        :ok
    end
  end
end
