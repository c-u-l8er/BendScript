defmodule IntersectionSignalTest do
  use ExUnit.Case
  doctest IntersectionSignal
  require Logger

  setup do
    test_name = :"#{__MODULE__}.#{System.unique_integer()}"
    {:ok, pid} = IntersectionSignal.start_link(name: test_name)
    %{signal: pid}
  end

  describe "initial state" do
    test "starts with correct initial signal states", %{signal: signal} do
      {:ok, drum} = IntersectionSignal.get_drum(signal)
      assert drum.memory == :ns_active
      assert drum.rotate.north_south == :green
      assert drum.rotate.east_west == :red
      assert drum.rotate.timer == 0
    end
  end

  describe "signal transitions" do
    test "completes full cycle", %{signal: signal} do
      # Initial state check
      status = IntersectionSignal.look(signal)
      assert status.north_south == :green
      assert status.east_west == :red

      # Force NS green -> yellow transition
      # Just over green duration
      IntersectionSignal.set_timer(signal, 4001)
      IntersectionSignal.force_tick(signal)

      status = IntersectionSignal.look(signal)
      assert status.memory == :ns_yellow
      assert status.north_south == :yellow
      assert status.east_west == :red

      # Force NS yellow -> red, EW red -> green transition
      # Just over yellow duration
      IntersectionSignal.set_timer(signal, 1001)
      GenServer.call(signal, {:drum, :ns_yellow, :tick})

      status = IntersectionSignal.look(signal)
      assert status.memory == :ew_active
      assert status.north_south == :red
      assert status.east_west == :green
    end
  end

  describe "continuous operation" do
    test "runs through multiple cycles with controlled timing", %{signal: signal} do
      # Test NS green -> yellow
      IntersectionSignal.set_timer(signal, 4001)
      IntersectionSignal.force_tick(signal)

      status = IntersectionSignal.look(signal)
      assert status.north_south == :yellow
      assert status.east_west == :red

      # Test NS yellow -> red, EW red -> green
      IntersectionSignal.set_timer(signal, 1001)
      GenServer.call(signal, {:drum, :ns_yellow, :tick})

      status = IntersectionSignal.look(signal)
      assert status.north_south == :red
      assert status.east_west == :green

      # Test EW green -> yellow
      IntersectionSignal.set_timer(signal, 4001)
      GenServer.call(signal, {:drum, :ew_active, :tick})

      status = IntersectionSignal.look(signal)
      assert status.north_south == :red
      assert status.east_west == :yellow

      # Test EW yellow -> red, NS red -> green (complete cycle)
      IntersectionSignal.set_timer(signal, 1001)
      GenServer.call(signal, {:drum, :ew_yellow, :tick})

      status = IntersectionSignal.look(signal)
      assert status.north_south == :green
      assert status.east_west == :red
    end
  end
end
