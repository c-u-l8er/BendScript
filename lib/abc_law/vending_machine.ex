defmodule VendingMachine do
  use KernelShtf.Gov
  require Logger

  fabric VendingMachine do
    # Define initial state
    def canvas(_) do
      {:ok, %{current_state: :idle, data: %{coins: 0, inventory: 5}}}
    end

    # Define states and their transitions
    pattern :idle do
      weave {:insert_coin, amount} do
        new_state = add_coins(amount, state)
        weft(to: :ready, state: new_state)
      end
    end

    # Effect definition moved outside state block
    texture :add_coins, [amount, state], state do
      Logger.info("ADD_COINS - Before: #{inspect(state)}")
      new_coins = state.data.coins + amount
      new_state = %{state | data: %{state.data | coins: new_coins}}
      Logger.info("ADD_COINS - After: #{inspect(new_state)}")
      new_state
    end

    pattern :ready do
      weave {:insert_coin, amount} do
        current_coins = state.data.coins
        Logger.info("READY - Current coins before add: #{current_coins}")

        new_state = add_coins(amount, state)
        Logger.info("READY - State after add_coins: #{inspect(new_state)}")

        # Try forcing the state update explicitly
        updated_state = %{
          current_state: :ready,
          data: %{
            coins: new_state.data.coins,
            inventory: state.data.inventory
          }
        }

        Logger.info("READY - Final state to be returned: #{inspect(updated_state)}")

        warp(state: updated_state)
      end

      weave :purchase do
        coins = state.data.coins
        inventory = state.data.inventory

        cond do
          coins >= 100 and inventory > 0 ->
            new_data = %{
              state.data
              | coins: coins - 100,
                inventory: inventory - 1
            }

            weft(to: :dispensing, state: %{state | data: new_data})

          inventory <= 0 ->
            # Inventory is empty; stay in :ready
            warp(state: state)

          true ->
            # Insufficient funds; stay in :ready
            warp(state: state)
        end
      end
    end

    pattern :dispensing do
      weave :dispense_complete do
        new_data = %{state.data | coins: 0}
        weft(to: :idle, state: %{state | data: new_data})
      end

      weave :other do
        # Keep state for any other events while dispensing
        warp(state: state)
      end
    end
  end
end
