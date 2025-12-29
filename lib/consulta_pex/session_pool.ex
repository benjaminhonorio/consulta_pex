defmodule ConsultaPex.SessionPool do
  use GenServer
  require Logger

  @default_checkout_timeout 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def checkout(timeout \\ @default_checkout_timeout) do
    GenServer.call(__MODULE__, :checkout, timeout)
  end

  def checkin(session_id) do
    GenServer.cast(__MODULE__, {:checkin, session_id})
  end

  def with_session(fun, timeout \\ @default_checkout_timeout) do
    case checkout(timeout) do
      {:ok, session_id} ->
        try do
          fun.(session_id)
        after
          checkin(session_id)
        end

      {:error, _} = error ->
        error
    end
  end

  def pool_status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def init(opts) do
    pool_size = opts[:pool_size] || 3

    state = %{
      pool_size: pool_size,
      available: MapSet.new(1..pool_size),
      in_use: %{},
      waiting: :queue.new()
    }

    Logger.info("SessionPool iniciado con #{pool_size} sesiones")
    {:ok, state}
  end

  @impl true
  def handle_call(:checkout, {pid, _} = from, state) do
    case MapSet.to_list(state.available) do
      [session_id | _] ->
        ref = Process.monitor(pid)

        new_state = %{
          state
          | available: MapSet.delete(state.available, session_id),
            in_use: Map.put(state.in_use, session_id, {pid, ref, System.monotonic_time()})
        }

        {:reply, {:ok, session_id}, new_state}

      [] ->
        # No hay sesiones disponibles, encolar
        new_waiting = :queue.in(from, state.waiting)
        {:noreply, %{state | waiting: new_waiting}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      pool_size: state.pool_size,
      available: MapSet.size(state.available),
      in_use: map_size(state.in_use),
      waiting: :queue.len(state.waiting)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:checkin, session_id}, state) do
    case Map.get(state.in_use, session_id) do
      {_pid, ref, _time} ->
        Process.demonitor(ref, [:flush])
        new_state = do_checkin(session_id, state)
        {:noreply, new_state}

      nil ->
        # Sesión no estaba en uso
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # El proceso que tenía una sesión murió
    case find_session_by_pid(state.in_use, pid) do
      {:ok, session_id} ->
        Logger.warning("Proceso #{inspect(pid)} murió, liberando sesión #{session_id}")
        new_state = do_checkin(session_id, state)
        {:noreply, new_state}

      :error ->
        {:noreply, state}
    end
  end

  defp do_checkin(session_id, state) do
    new_in_use = Map.delete(state.in_use, session_id)

    case :queue.out(state.waiting) do
      {{:value, {pid, _} = from}, new_waiting} ->
        # Hay alguien esperando, asignar sesión
        ref = Process.monitor(pid)

        new_state = %{
          state
          | in_use: Map.put(new_in_use, session_id, {pid, ref, System.monotonic_time()}),
            waiting: new_waiting
        }

        GenServer.reply(from, {:ok, session_id})
        new_state

      {:empty, _} ->
        # Nadie esperando, devolver sesión al pool
        %{state | available: MapSet.put(state.available, session_id), in_use: new_in_use}
    end
  end

  defp find_session_by_pid(in_use, pid) do
    case Enum.find(in_use, fn {_session_id, {p, _ref, _time}} -> p == pid end) do
      {session_id, _} -> {:ok, session_id}
      nil -> :error
    end
  end
end
