defmodule ConsultaPex.RedisStore do
  @redix :redix

  def get_cookies do
    Redix.command(@redix, ["GET", "sunat:cookies"])
  end

  def set_cookies(cookies) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    with {:ok, _} <- Redix.command(@redix, ["SET", "sunat:cookies", cookies]),
         {:ok, _} <- Redix.command(@redix, ["SET", "sunat:updated_at", timestamp]) do
      {:ok, timestamp}
    end
  end

  def get_updated_at do
    Redix.command(@redix, ["GET", "sunat:updated_at"])
  end
end
