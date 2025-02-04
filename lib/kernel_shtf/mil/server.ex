defmodule KernelShtf.Mil.Server do
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
          {response, _new_floppy} -> response
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
      {:ok, floppy} -> loop(module, floppy)
      {:error, reason} -> exit(reason)
    end
  end

  defp loop(module, floppy) do
    receive do
      {:call, from = {pid, _ref}, ref, request} ->
        case module.handle_call(request, from, floppy) do
          {:reply, reply, new_floppy} ->
            send(pid, {:reply, ref, reply})
            loop(module, new_floppy)
        end

      {:cast, request} ->
        case module.handle_cast(request, floppy) do
          {:noreply, new_floppy} -> loop(module, new_floppy)
        end

      msg ->
        case module.handle_info(msg, floppy) do
          {:noreply, new_floppy} -> loop(module, new_floppy)
        end
    end
  end
end
