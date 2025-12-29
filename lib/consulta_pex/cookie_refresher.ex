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
      refresh_interval: Application.get_env(:consulta_pex, :refresh_interval, :timer.minutes(60)),
      retry_interval: Application.get_env(:consulta_pex, :retry_interval, :timer.minutes(5))
    }

    send(self(), :check_and_refresh)
    {:ok, state}
  end

  @impl true
  def handle_info(:check_and_refresh, state) do
    case should_refresh?(state.refresh_interval) do
      true ->
        Logger.info("Cookies vencidas o no existen, haciendo login...")
        do_refresh(state)

      false ->
        Logger.info("Cookies válidas, esperando próximo refresh")
        schedule_refresh(state.refresh_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:refresh, state) do
    do_refresh(state)
  end

  defp should_refresh?(refresh_interval) do
    case RedisStore.get_updated_at() do
      {:ok, nil} ->
        true

      {:ok, timestamp_str} ->
        case DateTime.from_iso8601(timestamp_str) do
          {:ok, timestamp, _} ->
            age = DateTime.diff(DateTime.utc_now(), timestamp, :millisecond)
            age > refresh_interval * 0.9

          {:error, _} ->
            # Timestamp inválido = mejor refrescar
            true
        end

      {:error, _} ->
        true
    end
  end

  defp do_refresh(state) do
    case PlaywrightPort.login(state.credentials) do
      {:ok, cookies} ->
        RedisStore.set_cookies(cookies)
        Logger.info("Cookies actualizadas")
        schedule_refresh(state.refresh_interval)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Error en login: #{inspect(reason)}")
        schedule_refresh(state.retry_interval)
        {:noreply, state}
    end
  end

  defp schedule_refresh(interval) do
    Process.send_after(self(), :refresh, interval)
  end
end
