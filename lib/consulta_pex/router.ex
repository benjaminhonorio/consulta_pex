defmodule ConsultaPex.Router do
  use Plug.Router
  require Logger
  alias ConsultaPex.{RedisStore, SessionPool, SunatApi}

  plug(Plug.Logger)
  plug(:match)
  plug(:maybe_authenticate)
  plug(:dispatch)

  get "/health" do
    pool_status = SessionPool.pool_status()
    sessions_info = get_sessions_info(pool_status.pool_size)

    if sessions_info.ready > 0 do
      send_json(conn, 200, %{status: "ok"})
    else
      send_json(conn, 503, %{status: "degraded", message: "no sessions ready"})
    end
  end

  get "/pool/status" do
    pool_status = SessionPool.pool_status()
    sessions_info = get_sessions_info(pool_status.pool_size)

    send_json(conn, 200, %{
      pool: %{
        size: pool_status.pool_size,
        available: pool_status.available,
        in_use: pool_status.in_use,
        waiting: pool_status.waiting
      },
      sessions: %{
        ready: sessions_info.ready,
        oldest_update: sessions_info.oldest_update
      }
    })
  end

  get "/dni/:numero" do
    case SunatApi.consultar_dni(numero) do
      {:ok, data} ->
        send_json(conn, 200, %{success: true, nombre: data.nombre})

      {:error, reason} ->
        Logger.warning("GET /dni/#{numero} failed: #{format_error(reason)}")
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
        Logger.warning("GET /ruc/#{numero} failed: #{format_error(reason)}")
        send_json(conn, 400, %{success: false, error: format_error(reason)})
    end
  end

  match _ do
    send_json(conn, 404, %{error: "not found"})
  end

  @public_paths ["/health"]

  defp maybe_authenticate(%{request_path: path} = conn, _opts) when path in @public_paths do
    conn
  end

  defp maybe_authenticate(conn, _opts) do
    ConsultaPex.Plugs.ApiKeyAuth.call(conn, [])
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

  defp get_sessions_info(pool_size) do
    sessions =
      Enum.map(1..pool_size, fn session_id ->
        case RedisStore.get_session_updated_at(session_id) do
          {:ok, nil} -> nil
          {:ok, timestamp} -> timestamp
          _ -> nil
        end
      end)

    ready = Enum.count(sessions, &(&1 != nil))
    oldest = sessions |> Enum.reject(&is_nil/1) |> Enum.min(fn -> nil end)

    %{ready: ready, oldest_update: oldest}
  end
end
