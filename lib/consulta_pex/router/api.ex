defmodule ConsultaPex.Router.Api do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  forward("/v1", to: ConsultaPex.Router.V1)

  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not found"}))
  end
end
