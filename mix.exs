defmodule BenBen.MixProject do
  use Mix.Project

  def project do
    [
      app: :ben_ben,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Add the following to enable distributed tests
      elixirc_options: [
        {:warnings_as_errors, false}
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        test: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ra, :sasl],
      mod: {RaRa.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:ra, "~> 2.15"}
    ]
  end
end
