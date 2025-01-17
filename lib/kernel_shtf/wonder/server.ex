defmodule KernelShtf.Wonder.Server do
  @moduledoc """
  The core server implementation that handles the process lifecycle and message passing.
  """

  def start_link(module, init_arg) do
    pid = spawn_link(__MODULE__, :init, [module, init_arg])
    {:ok, pid}
  end

  def call(server, request) do
    ref = make_ref()
    send(server, {:call, {self(), ref}, ref, request})

    receive do
      {:reply, ^ref, reply} ->
        case reply do
          {response, _new_state} -> response
          other -> other
        end
    after
      5000 -> {:error, :timeout}
    end
  end

  def cast(server, request) do
    send(server, {:cast, request})
    :ok
  end

  def init(module, init_arg) do
    case module.init(init_arg) do
      {:ok, state} -> loop(module, state)
      {:error, reason} -> exit(reason)
    end
  end

  defp loop(module, state) do
    receive do
      {:call, from = {pid, _ref}, ref, request} ->
        case module.handle_call(request, from, state) do
          {:reply, reply, new_state} ->
            send(pid, {:reply, ref, reply})
            loop(module, new_state)
        end

      {:cast, request} ->
        case module.handle_cast(request, state) do
          {:noreply, new_state} -> loop(module, new_state)
        end

      msg ->
        case module.handle_info(msg, state) do
          {:noreply, new_state} -> loop(module, new_state)
        end
    end
  end
end
