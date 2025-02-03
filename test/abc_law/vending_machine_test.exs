defmodule VendingMachineTest do
  use ExUnit.Case
  doctest VendingMachine
  require Logger

  setup do
    Logger.info("Starting test setup")
    test_name = :"#{__MODULE__}.#{System.unique_integer()}"
    {:ok, pid} = VendingMachine.start_link(name: test_name)
    Logger.info("Test setup complete with pid: #{inspect(pid)}")
    %{machine: pid}
  end

  describe "initial state" do
    test "starts in idle state with no coins", %{machine: machine} do
      Logger.info("Running initial state test")
      result = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(result)}")
      assert {:ok, drum} = result
      assert drum.memory == :idle
      assert drum.rotate == %{coins: 0, inventory: 5}
    end
  end

  describe "coin insertion" do
    test "accepts coins and transitions to ready", %{machine: machine} do
      Logger.info("Running coin insertion test")

      Logger.info("Running coin insertion test")
      result = GenServer.call(machine, {:drum, :idle, {:insert_coin, 100}})
      Logger.info("Transition result: #{inspect(result)}")
      assert {:ok, :ready} = result

      result = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(result)}")
      assert {:ok, drum} = result
      assert drum.rotate.coins == 100
    end

    test "accumulates multiple coin insertions", %{machine: machine} do
      Logger.info("TEST - Starting coin accumulation test")

      result1 = GenServer.call(machine, {:drum, :idle, {:insert_coin, 50}})
      Logger.info("TEST - After first insertion: #{inspect(result1)}")

      {:ok, drum1} = VendingMachine.get_drum(machine)
      Logger.info("TEST - State after first insertion: #{inspect(drum1)}")

      result2 = GenServer.call(machine, {:drum, :ready, {:insert_coin, 50}})
      Logger.info("TEST - After second insertion: #{inspect(result2)}")

      {:ok, drum2} = VendingMachine.get_drum(machine)
      Logger.info("TEST - State after second insertion: #{inspect(drum2)}")

      assert drum2.rotate.coins == 100
    end
  end

  describe "purchase handling" do
    @tag run: true
    test "allows purchase with sufficient funds", %{machine: machine} do
      # Insert enough coins
      GenServer.call(machine, {:drum, :idle, {:insert_coin, 100}})

      # Attempt purchase
      assert {:ok, :dispensing} = GenServer.call(machine, {:drum, :ready, :purchase})

      # Check state updates
      result = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(result)}")
      assert {:ok, drum} = result
      assert drum.rotate.coins == 0
      assert drum.rotate.inventory == 4
    end

    test "prevents purchase without sufficient funds", %{machine: machine} do
      # Insert insufficient coins
      GenServer.call(machine, {:drum, :idle, {:insert_coin, 50}})

      # Attempt purchase
      assert {:ok, :ready} = GenServer.call(machine, {:drum, :ready, :purchase})

      # Check state remains unchanged
      result = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(result)}")
      assert {:ok, drum} = result
      assert drum.rotate.coins == 50
      assert drum.rotate.inventory == 5
    end

    test "prevents purchase with empty inventory", %{machine: machine} do
      # Set BOTH current_state and data
      new_state = %{memory: :ready, rotate: %{coins: 500, inventory: 0}}
      :sys.replace_state(machine, fn _ -> new_state end)

      # Attempt purchase
      assert {:ok, :ready} = GenServer.call(machine, {:drum, :ready, :purchase})

      # Verify state remains unchanged
      assert {:ok, %{memory: :ready, rotate: %{inventory: 0}}} = VendingMachine.get_drum(machine)
    end
  end

  describe "dispensing process" do
    @tag run: true
    test "completes dispensing cycle", %{machine: machine} do
      # Get to dispensing state
      GenServer.call(machine, {:drum, :idle, {:insert_coin, 100}})
      GenServer.call(machine, {:drum, :ready, :purchase})

      # Complete dispensing
      assert {:ok, :idle} = GenServer.call(machine, {:drum, :dispensing, :dispense_complete})

      # Verify final state
      result = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(result)}")
      assert {:ok, drum} = result
      assert drum.rotate.coins == 0
      assert drum.rotate.inventory == 4
    end
  end

  describe "full purchase cycle" do
    @tag run: true
    test "handles complete purchase flow", %{machine: machine} do
      # Initial state check
      initial_state = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(initial_state)}")
      assert {:ok, drum} = initial_state
      assert drum.rotate.coins == 0
      assert drum.rotate.inventory == 5

      # Insert coins
      assert {:ok, :ready} = GenServer.call(machine, {:drum, :idle, {:insert_coin, 100}})

      # Purchase
      assert {:ok, :dispensing} = GenServer.call(machine, {:drum, :ready, :purchase})

      # Complete dispensing
      assert {:ok, :idle} = GenServer.call(machine, {:drum, :dispensing, :dispense_complete})

      # Final state check
      final_state = VendingMachine.get_drum(machine)
      Logger.info("Got state: #{inspect(final_state)}")
      assert {:ok, drum} = final_state
      assert drum.rotate.coins == 0
      assert drum.rotate.inventory == 4
    end
  end
end
