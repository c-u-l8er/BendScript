defmodule VendingMachine do
  use KernelShtf.Gov

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
      %{state | data: %{state.data | coins: state.data.coins + amount}}
    end

    pattern :ready do
      weave :purchase do
        cond do
          state.data.coins >= 100 and state.data.inventory > 0 ->
            new_data = %{
              state.data
              | coins: state.data.coins - 100,
                inventory: state.data.inventory - 1
            }

            weft(to: :dispensing, state: %{state | data: new_data})

          true ->
            warp(state: state)
        end
      end

      weave {:insert_coin, amount} do
        new_state = add_coins(amount, state)
        warp(state: new_state)
      end
    end

    pattern :dispensing do
      weave :dispense_complete do
        weft(to: :idle, state: state)
      end
    end
  end
end
