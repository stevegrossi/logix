defmodule Logix.MixProject do
  use Mix.Project

  def project do
    [
      app: :logix,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        "test.watch": :test,
        lint: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.0"},
      {:dialyxir, "~> 1.3", runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      lint: ["test", "dialyzer"]
    ]
  end
end
