defmodule ConsultaPex.CookieRefresher do
  use GenServer
  require Logger
  alias ConsultaPex.{PlaywrightPort, RedisStore}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      credentials: %{
        ruc: opts[:ruc],
        usuario_sol: opts[:usuario_sol],
        clave_sol: opts[:clave_sol]
      },
      pool_size: Application.fetch_env!(:consulta_pex, :pool_size),
      refresh_interval: Application.fetch_env!(:consulta_pex, :refresh_interval),
      retry_interval: Application.fetch_env!(:consulta_pex, :retry_interval)
    }

    send(self(), :check_and_refresh)
    {:ok, state}
  end

  @impl true
  def handle_info(:check_and_refresh, state) do
    refresh_all_sessions(state)
    schedule_refresh(state.refresh_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh_all_sessions(state)
    schedule_refresh(state.refresh_interval)
    {:noreply, state}
  end

  defp refresh_all_sessions(state) do
    Logger.info("Starting refresh of #{state.pool_size} sessions...")

    results =
      Enum.map(1..state.pool_size, fn session_id ->
        refresh_session(session_id, state)
      end)

    success_count = Enum.count(results, &match?(:ok, &1))
    error_count = Enum.count(results, &match?({:error, _}, &1))

    Logger.info("Refresh completed: #{success_count} successful, #{error_count} failed")
  end

  defp refresh_session(session_id, state) do
    case should_refresh_session?(session_id, state.refresh_interval) do
      true ->
        Logger.info("Session #{session_id}: refreshing...")
        do_refresh_session(session_id, state)

      false ->
        Logger.debug("Session #{session_id}: cookies still valid")
        :ok
    end
  end

  defp should_refresh_session?(session_id, refresh_interval) do
    case RedisStore.get_session_updated_at(session_id) do
      {:ok, nil} ->
        true

      {:ok, timestamp_str} ->
        case DateTime.from_iso8601(timestamp_str) do
          {:ok, timestamp, _} ->
            age = DateTime.diff(DateTime.utc_now(), timestamp, :millisecond)
            age > refresh_interval * 0.9

          {:error, _} ->
            true
        end

      {:error, _} ->
        true
    end
  end

  defp do_refresh_session(session_id, state) do
    case PlaywrightPort.login(state.credentials) do
      {:ok, cookies} ->
        case RedisStore.set_session_cookies(session_id, cookies) do
          {:ok, _} ->
            Logger.info("Session #{session_id}: cookies updated")
            :ok

          {:error, reason} ->
            Logger.error("Session #{session_id}: error saving to Redis: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Session #{session_id}: login error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_refresh(interval) do
    Process.send_after(self(), :refresh, interval)
  end
end
