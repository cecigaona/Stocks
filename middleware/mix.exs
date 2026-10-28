defmodule Middleware.MixProject do
  use Mix.Project

  def project do
    [
      app: :middleware,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Middleware.Application, []},
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:grpc, "~> 0.9.0"},
      {:protobuf, "~> 0.12"},
      {:cowlib, "~> 2.13", override: true},
      {:gen_stage, "~> 1.2"}
    ]
  end
end
