defmodule IntersectionSignal do
  use KernelShtf.Gov
  require Logger

  # 5 seconds
  @red_duration 5000
  # 4 seconds
  @green_duration 4000
  # 1 second
  @yellow_duration 1000

  fabric IntersectionSignal do
    def canvas(_) do
      {:ok,
       %{
         memory: :ns_active,
         rotate: %{
           north_south: :green,
           east_west: :red,
           timer: 0,
           last_tick: System.monotonic_time(:millisecond)
         }
       }}
    end

    # North-South Active Phase
    pattern :ns_active do
      # Handle timer ticks
      weave :tick do
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - drum.rotate.last_tick
        new_timer = drum.rotate.timer + elapsed

        new_state = %{drum | rotate: %{drum.rotate | timer: new_timer, last_tick: current_time}}

        case {drum.rotate.north_south, new_timer} do
          {:green, t} when t >= @green_duration ->
            Logger.info("NS: Green -> Yellow")

            weft(
              to: :ns_yellow,
              drum: %{new_state | rotate: %{new_state.rotate | north_south: :yellow, timer: 0}}
            )

          _ ->
            warp(drum: new_state)
        end
      end
    end

    pattern :ns_yellow do
      weave :tick do
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - drum.rotate.last_tick
        new_timer = drum.rotate.timer + elapsed

        new_state = %{drum | rotate: %{drum.rotate | timer: new_timer, last_tick: current_time}}

        if new_timer >= @yellow_duration do
          Logger.info("NS: Yellow -> Red, EW: Red -> Green")

          weft(
            to: :ew_active,
            drum: %{
              new_state
              | rotate: %{new_state.rotate | north_south: :red, east_west: :green, timer: 0}
            }
          )
        else
          warp(drum: new_state)
        end
      end
    end

    # East-West Active Phase
    pattern :ew_active do
      weave :tick do
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - drum.rotate.last_tick
        new_timer = drum.rotate.timer + elapsed

        new_state = %{drum | rotate: %{drum.rotate | timer: new_timer, last_tick: current_time}}

        case {drum.rotate.east_west, new_timer} do
          {:green, t} when t >= @green_duration ->
            Logger.info("EW: Green -> Yellow")

            weft(
              to: :ew_yellow,
              drum: %{new_state | rotate: %{new_state.rotate | east_west: :yellow, timer: 0}}
            )

          _ ->
            warp(drum: new_state)
        end
      end
    end

    pattern :ew_yellow do
      weave :tick do
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - drum.rotate.last_tick
        new_timer = drum.rotate.timer + elapsed

        new_state = %{drum | rotate: %{drum.rotate | timer: new_timer, last_tick: current_time}}

        if new_timer >= @yellow_duration do
          Logger.info("EW: Yellow -> Red, NS: Red -> Green")

          weft(
            to: :ns_active,
            drum: %{
              new_state
              | rotate: %{new_state.rotate | east_west: :red, north_south: :green, timer: 0}
            }
          )
        else
          warp(drum: new_state)
        end
      end
    end
  end

  # Helper functions to start the timer and get signal states
  def start_timer(pid) do
    Process.send_after(pid, {:tick_timer, self()}, 100)
  end

  def get_signals(pid) do
    {:ok, drum} = get_drum(pid)
    {drum.rotate.north_south, drum.rotate.east_west}
  end

  def force_tick(pid) do
    GenServer.call(pid, {:drum, :ns_active, :tick})
  end

  def set_timer(pid, time) do
    {:ok, drum} = get_drum(pid)
    new_state = %{drum | rotate: %{drum.rotate | timer: time}}
    :sys.replace_state(pid, fn _ -> new_state end)
  end

  def look(pid) do
    {:ok, drum} = get_drum(pid)

    %{
      memory: drum.memory,
      north_south: drum.rotate.north_south,
      east_west: drum.rotate.east_west,
      timer: drum.rotate.timer
    }
  end
end
