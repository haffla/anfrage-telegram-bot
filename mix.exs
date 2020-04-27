defmodule Anfrage.MixProject do
  use Mix.Project

  def project do
    [
      app: :anfrage,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :plug_cowboy],
      mod: {Anfrage.Application, []},
      applications: [:nadia]
    ]
  end

  defp deps do
    [
      {:nadia, "~> 0.6.0"},
      {:httpoison, "~> 1.6"},
      {:floki, "~> 0.26.0"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
