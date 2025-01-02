import Config

config :logger, :console,
  level: :debug,
  format: "$time $metadata[$level] $message\n"

config :ra,
  # Ensure this directory exists and is writable
  data_dir: '/tmp/ra_data'
