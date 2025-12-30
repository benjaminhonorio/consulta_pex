defmodule ConsultaPex.Router do
  use Plug.Router
  alias ConsultaPex.{RedisStore, SessionPool}

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

  forward("/api", to: ConsultaPex.Router.Api)

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

  defp send_json(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end

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
