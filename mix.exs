defmodule MixErlydtl.Mixfile do
  use Mix.Project

  def project, do: [
    app: :mix_erlydtl,
    version: "0.1.0",
    elixir: "~> 1.0",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: [
      {:erlydtl, ">= 0.0.0"},
    ],
  ]
end
