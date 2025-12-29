defmodule ConsultaPex.Router do
  use Plug.Router
  alias ConsultaPex.RedisStore
  alias ConsultaPex.SunatApi

  plug(:match)
  plug(:dispatch)

  get "/health" do
    case RedisStore.get_cookies() do
      {:ok, nil} ->
        send_json(conn, 503, %{status: "error", message: "no cookies"})

      {:ok, _} ->
        {:ok, updated_at} = RedisStore.get_updated_at()
        send_json(conn, 200, %{status: "ok", cookies_updated_at: updated_at})

      {:error, reason} ->
        send_json(conn, 503, %{status: "error", message: inspect(reason)})
    end
  end

  get "/dni/:numero" do
    case SunatApi.consultar_dni(numero) do
      {:ok, data} ->
        send_json(conn, 200, %{success: true, nombre: data.nombre})

      {:error, reason} ->
        send_json(conn, 400, %{success: false, error: format_error(reason)})
    end
  end

  get "/ruc/:numero" do
    case SunatApi.consultar_ruc(numero) do
      {:ok, data} ->
        send_json(conn, 200, %{
          success: true,
          razon_social: data.razon_social,
          domicilios: data.domicilios
        })

      {:error, reason} ->
        send_json(conn, 400, %{success: false, error: format_error(reason)})
    end
  end

  match _ do
    send_json(conn, 404, %{error: "not found"})
  end

  # Helpers

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
