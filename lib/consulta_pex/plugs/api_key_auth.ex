defmodule ConsultaPex.Plugs.ApiKeyAuth do
  @moduledoc """
  Plug that verifies the X-API-Key header against the configured API key.
  """
  import Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected_key = Application.fetch_env!(:consulta_pex, :api_key)

    case get_req_header(conn, "x-api-key") do
      [^expected_key] ->
        conn

      [_invalid] ->
        conn |> send_unauthorized("invalid api key") |> halt()

      [] ->
        conn |> send_unauthorized("missing api key") |> halt()
    end
  end

  defp send_unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "unauthorized", message: message}))
  end
end
