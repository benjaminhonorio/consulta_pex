defmodule ConsultaPex.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = Application.fetch_env!(:consulta_pex, :http_port)
    pool_size = Application.fetch_env!(:consulta_pex, :pool_size)
    ruc = Application.fetch_env!(:consulta_pex, :ruc)
    usuario_sol = Application.fetch_env!(:consulta_pex, :usuario_sol)
    clave_sol = Application.fetch_env!(:consulta_pex, :clave_sol)

    children = [
      {Redix, {Application.fetch_env!(:consulta_pex, :redis_url), [name: :redix]}},
      ConsultaPex.PlaywrightPort,
      {ConsultaPex.SessionPool, pool_size: pool_size},
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
