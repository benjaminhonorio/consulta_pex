defmodule ConsultaPex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:consulta_pex, :http_port, 4000)
    ruc = Application.get_env(:consulta_pex, :ruc)
    usuario_sol = Application.get_env(:consulta_pex, :usuario_sol)
    clave_sol = Application.get_env(:consulta_pex, :clave_sol)

    children = [
      {Redix, {Application.get_env(:consulta_pex, :redis_url, "redis://localhost:6379"), [name: :redix]}},
      ConsultaPex.PlaywrightPort,
      {ConsultaPex.CookieRefresher, ruc: ruc, usuario_sol: usuario_sol, clave_sol: clave_sol},
      {Bandit, plug: ConsultaPex.Router, port: port}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ConsultaPex.Supervisor]

    result = Supervisor.start_link(children, opts)

    if match?({:ok, _}, result),
      do: Logger.info("ConsultaPex running on http://localhost:#{port}")

    result
  end
end
