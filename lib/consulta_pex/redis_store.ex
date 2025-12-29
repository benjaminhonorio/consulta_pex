defmodule ConsultaPex.RedisStore do
  @redix :redix

  # Funciones legacy (para compatibilidad con consultas DNI)
  def get_cookies do
    get_session_cookies(1)
  end

  def set_cookies(cookies) do
    set_session_cookies(1, cookies)
  end

  def get_updated_at do
    get_session_updated_at(1)
  end

  # Funciones para pool de sesiones
  def get_session_cookies(session_id) do
    Redix.command(@redix, ["GET", session_key(session_id, :cookies)])
  end

  def set_session_cookies(session_id, cookies) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    with {:ok, _} <- Redix.command(@redix, ["SET", session_key(session_id, :cookies), cookies]),
         {:ok, _} <-
           Redix.command(@redix, ["SET", session_key(session_id, :updated_at), timestamp]) do
      {:ok, timestamp}
    end
  end

  def get_session_updated_at(session_id) do
    Redix.command(@redix, ["GET", session_key(session_id, :updated_at)])
  end

  defp session_key(session_id, :cookies), do: "sunat:session:#{session_id}:cookies"
  defp session_key(session_id, :updated_at), do: "sunat:session:#{session_id}:updated_at"
end
