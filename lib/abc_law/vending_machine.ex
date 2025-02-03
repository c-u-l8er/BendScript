defmodule VendingMachine do
  use KernelShtf.Gov
  require Logger

  fabric VendingMachine do
    # Define initial state
    def canvas(_) do
      {:ok, %{memory: :idle, rotate: %{coins: 0, inventory: 5}}}
    end

    # Define states and their transitions
    pattern :idle do
      weave {:insert_coin, amount} do
        new_state = add_coins(amount, drum)
        weft(to: :ready, drum: new_state)
      end
    end

    # Effect definition moved outside state block
    texture :add_coins, [amount, drum], drum do
      Logger.info("ADD_COINS - Before: #{inspect(drum)}")
      new_coins = drum.rotate.coins + amount
      new_state = %{drum | rotate: %{drum.rotate | coins: new_coins}}
      Logger.info("ADD_COINS - After: #{inspect(new_state)}")
      new_state
    end

    pattern :ready do
      weave {:insert_coin, amount} do
        current_coins = drum.rotate.coins
        Logger.info("READY - Current coins before add: #{current_coins}")

        new_state = add_coins(amount, drum)
        Logger.info("READY - State after add_coins: #{inspect(new_state)}")

        # Try forcing the state update explicitly
        updated_state = %{
          memory: :ready,
          rotate: %{
            coins: new_state.rotate.coins,
            inventory: drum.rotate.inventory
          }
        }

        Logger.info("READY - Final state to be returned: #{inspect(updated_state)}")

        warp(drum: updated_state)
      end

      weave :purchase do
        coins = drum.rotate.coins
        inventory = drum.rotate.inventory

        cond do
          coins >= 100 and inventory > 0 ->
            new_data = %{
              drum.rotate
              | coins: coins - 100,
                inventory: inventory - 1
            }

            Logger.info("DISPENSING")
            weft(to: :dispensing, drum: %{drum | rotate: new_data})

          inventory <= 0 ->
            Logger.info("Inventory is empty; stay in :ready")
            warp(drum: drum)

          true ->
            Logger.info("Insufficient funds; stay in :ready")
            warp(drum: drum)
        end
      end
    end

    pattern :dispensing do
      weave :dispense_complete do
        new_data = %{drum.rotate | coins: 0}
        weft(to: :idle, drum: %{drum | rotate: new_data})
      end

      # Add a catch-all for other events in dispensing state
      weave :other do
        warp(drum: drum)
      end
    end
  end
end
