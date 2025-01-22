defmodule KernelShtf.Race do
  @moduledoc """
  Provides a unique macro-based DSL for working with GenStage, Flow and Broadway.
  Makes these powerful libraries more ergonomic to use while leveraging their
  battle-tested implementations.
  """

  require Logger

  defmacro __using__(_opts) do
    quote do
      import KernelShtf.Race
      require Logger

      # Import the underlying libraries
      require GenStage
      require Flow
      require Broadway
    end
  end

  @doc """
  Defines a track or pipeline using Broadway.
  Provides a clean DSL for configuring producers, processors and batchers.
  """
  defmacro track(name, do: block) do
    quote do
      defmodule unquote(name) do
        use Broadway

        def start_link(opts) do
          name = opts[:name] || raise ArgumentError, "missing required :name option"
          broadway_opts = broadway_config() |> Keyword.put(:name, name)
          Broadway.start_link(__MODULE__, broadway_opts)
        end

        unquote(block)
      end
    end
  end

  @doc """
  Configures Broadway producers (track checkpoints) in a declarative way.
  """
  defmacro checkpoints(opts) do
    quote do
      def handle_message(_, message, _) do
        Broadway.Message.put_data(message, message.data)
      end

      def transform_message(event, _opts) do
        %Broadway.Message{
          data: event,
          acknowledger: {Broadway.NoopAcknowledger, :ack_ref, :ok}
        }
      end

      def broadway_config do
        [
          producer: [
            module: unquote(opts[:module]),
            transformer: {__MODULE__, :transform_message, []},
            concurrency: unquote(opts[:concurrency] || 1)
          ],
          processors: [
            default: [
              concurrency: unquote(opts[:checker_concurrency] || 1)
            ]
          ],
          batchers: [
            default: [
              batch_size: unquote(opts[:batch_size] || 100),
              batch_timeout: unquote(opts[:batch_timeout] || 1000),
              concurrency: unquote(opts[:batcher_concurrency] || 1)
            ]
          ]
        ]
      end
    end
  end

  @doc """
  Creates a Flow from an enumerable with a more declarative syntax.
  """
  defmacro flow(enumerable, opts \\ []) do
    quote do
      Flow.from_enumerable(
        unquote(enumerable),
        max_demand: unquote(opts[:max_demand] || 1000),
        min_demand: unquote(opts[:min_demand] || 500),
        stages: unquote(opts[:stages] || System.schedulers_online())
      )
    end
  end

  @doc """
  Creates a Flow from a GenStage producer with cleaner syntax.
  """
  defmacro flow_from_stage(producer, opts \\ []) do
    quote do
      Flow.from_stages(
        [unquote(producer)],
        max_demand: unquote(opts[:max_demand] || 1000),
        min_demand: unquote(opts[:min_demand] || 500),
        stages: unquote(opts[:stages] || System.schedulers_online())
      )
    end
  end

  @doc """
  Defines a GenStage producer (track jump) with simplified syntax.
  """
  defmacro jump(name, do: block) do
    quote do
      defmodule unquote(name) do
        use GenStage

        def start_link(opts \\ []) do
          GenStage.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          {:producer, opts}
        end

        unquote(block)
      end
    end
  end

  @doc """
  Defines a GenStage consumer (track landing with gap to jump) with simplified syntax.
  """
  defmacro land(name, gap_to, do: block) do
    quote do
      defmodule unquote(name) do
        use GenStage

        def start_link(opts \\ []) do
          GenStage.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          {:consumer, opts, subscribe_to: unquote(gap_to)}
        end

        unquote(block)
      end
    end
  end

  @doc """
  Simplified partition macro for Flow.
  """
  defmacro partition(flow, opts) do
    quote do
      Flow.partition(
        unquote(flow),
        stages: unquote(opts[:stages] || System.schedulers_online()),
        key: unquote(opts[:key] || (& &1))
      )
    end
  end

  @doc """
  Simplified window macro for Flow.
  """
  defmacro window(flow, type, opts \\ []) do
    window_fn =
      case type do
        :count -> quote do: Flow.Window.count(unquote(opts[:count] || 10_000))
        :global -> quote do: Flow.Window.global()
        :periodic -> quote do: Flow.Window.periodic(unquote(opts[:duration] || 1000))
        :session -> quote do: Flow.Window.session(unquote(opts[:timeout] || 1000))
      end

    quote do
      Flow.partition(
        unquote(flow),
        window: unquote(window_fn),
        stages: unquote(opts[:stages] || System.schedulers_online())
      )
    end
  end
end
