defmodule Arena.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :arena,
      version: "0.2.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]

  def application, do: [extra_applications: [:logger, :crypto], mod: {Arena.Application, []}]

  defp deps,
    do: [
      {:bandit, "~> 1.14"},
      {:plug, "~> 1.18"},
      {:websock_adapter, "~> 0.7"},
      {:jason, "~> 1.4"}
    ]
end
