defmodule TransactionalOutbox.MixProject do
  use Mix.Project

  def project do
    [
      app: :transactional_outbox,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      # Docs
      name: "TransactionalOutbox",
      source_url: "https://github.com/bcredi/transactional_outbox",
      homepage_url: "https://github.com/bcredi/transactional_outbox",
      docs: [
        main: "TransactionalOutbox",
        # logo: "path/to/logo.png",
        extras: ["README.md"]
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
      {:postgrex, ">= 0.0.0"},
      {:ecto_sql, "~> 3.0"},
      {:jason, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
