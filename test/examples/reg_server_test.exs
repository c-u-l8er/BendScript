defmodule RegServerTest do
  use ExUnit.Case, async: true

  describe "Counter with RegServer" do
    setup do
      {:ok, pid} = Counter.start_link([])
      {:ok, server: pid}
    end

    test "initial count is 0", %{server: pid} do
      assert Counter.get_count(pid) == 0
    end

    test "increment increases count", %{server: pid} do
      assert Counter.increment(pid, 5) == 5
      assert Counter.get_count(pid) == 5
    end

    test "multiple increments accumulate", %{server: pid} do
      assert Counter.increment(pid, 3) == 3
      assert Counter.increment(pid, 2) == 5
      assert Counter.get_count(pid) == 5
    end

    test "reset sets count back to 0", %{server: pid} do
      Counter.increment(pid, 10)
      assert Counter.get_count(pid) == 10

      Counter.reset(pid)
      # Add a small delay to ensure the async reset completes
      Process.sleep(10)
      assert Counter.get_count(pid) == 0
    end

    test "server maintains state between calls", %{server: pid} do
      Counter.increment(pid, 3)
      Counter.increment(pid, 2)
      Counter.increment(pid, 1)
      assert Counter.get_count(pid) == 6
    end

    test "handles multiple concurrent calls", %{server: pid} do
      tasks = for i <- 1..5 do
        Task.async(fn -> Counter.increment(pid, i) end)
      end

      _results = Task.await_many(tasks)
      assert Enum.sum(1..5) == Counter.get_count(pid)
    end

    test "server survives unexpected messages", %{server: pid} do
      send(pid, :unexpected_message)
      assert Counter.get_count(pid) == 0  # Server should still be responsive
      assert Counter.increment(pid, 1) == 1
    end
  end

  describe "RegServer error handling" do
    test "timeout on call to non-existent server" do
      assert RegServer.Server.call(self(), {:any, :request}) == {:error, :timeout}
    end

    test "cast to non-existent server doesn't raise" do
      assert RegServer.Server.cast(self(), {:any, :request}) == :ok
    end
  end

  describe "RegServer child_spec" do
    test "generates valid child specification" do
      spec = Counter.child_spec([])
      assert spec.id == Counter
      assert spec.type == :worker
      assert spec.restart == :permanent
      assert spec.shutdown == 5000
      assert {Counter, :start_link, [[]]} = spec.start
    end
  end
end
