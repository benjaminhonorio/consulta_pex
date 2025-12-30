defmodule ConsultaPex.PlaywrightPort do
  use GenServer
  require Logger

  alias ConsultaPex.SunatEndpoints

  @script_path "priv/playwright/dist/login.js"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def login(credentials) do
    GenServer.call(__MODULE__, {:login, credentials}, :timer.minutes(3))
  end

  @impl true
  def init(_) do
    node_path = System.find_executable("node")
    script = Path.expand(@script_path)

    port = Port.open({:spawn_executable, node_path}, [:binary, :exit_status, {:args, [script]}])

    {:ok, %{port: port, caller: nil}}
  end

  @impl true
  def handle_call({:login, credentials}, from, state) do
    command =
      Jason.encode!(%{
        action: "login",
        credentials: credentials,
        login_url: SunatEndpoints.login_url(),
        cookie_domain: SunatEndpoints.cookie_domain()
      })

    Port.command(state.port, command <> "\n")
    {:noreply, %{state | caller: from}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port, caller: nil} = state) do
    Logger.debug("Unexpected data from port: #{inspect(data)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port, caller: caller} = state) do
    case Jason.decode(data) do
      {:ok, %{"ok" => true, "cookies" => cookies}} -> GenServer.reply(caller, {:ok, cookies})
      {:ok, %{"ok" => false, "error" => error}} -> GenServer.reply(caller, {:error, error})
      {:error, _} -> GenServer.reply(caller, {:error, :invalid_json})
    end

    {:noreply, %{state | caller: nil}}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Logger.error("Node.js exit con status #{status}")
    {:stop, :port_closed, state}
  end
end
