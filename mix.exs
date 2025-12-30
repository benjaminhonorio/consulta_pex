defmodule ConsultaPex.MixProject do
  use Mix.Project

  def project do
    [
      app: :consulta_pex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        consulta_pex: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ConsultaPex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~>1.19"},
      {:bandit, "~>1.9"},
      {:jason, "~>1.4"},
      {:req, "~>0.5"},
      {:redix, "~>1.5"}
    ]
  end
end
