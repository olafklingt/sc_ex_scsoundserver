defmodule ScExScsoundserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :sc_ex_scsoundserver,
      version: "0.1.0",
      elixir: "~> 1.10",
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:sc_ex_scsoundserver, :sc_ex_synthdef]
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:typed_struct, "~> 0.2.0"},
      {:osc, "~> 0.1.2"},
      {:sc_ex_synthdef, path: "../../github/sc_ex_synthdef/"}
    ]
  end
end
