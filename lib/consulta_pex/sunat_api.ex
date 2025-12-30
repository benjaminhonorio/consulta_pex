defmodule ConsultaPex.SunatApi do
  require Logger
  alias ConsultaPex.{RedisStore, SessionPool, SunatEndpoints}

  # Para DNI → solo retorna nombre, desde sunat no hay de donde sacar los domicilios y para las boletas no es necesario
  def consultar_dni(dni) do
    with {:ok, cookies} <- get_cookies(),
         {:ok, nombre} <- validar_adquiriente(dni, 1, cookies) do
      {:ok, %{nombre: nombre}}
    end
  end

  # Para RUC → retorna razón social + domicilios (usa pool para evitar race conditions porque sunat mantiene un estado de lado del servidor para una determinada sesion)
  def consultar_ruc(ruc) do
    SessionPool.with_session(fn session_id ->
      with {:ok, cookies} <- get_session_cookies(session_id),
           {:ok, razon_social} <- validar_adquiriente(ruc, 6, cookies),
           {:ok, domicilios} <- get_domicilios(cookies) do
        {:ok, %{razon_social: razon_social, domicilios: domicilios}}
      end
    end)
  end

  defp get_cookies do
    case RedisStore.get_cookies() do
      {:ok, nil} ->
        Logger.warning("No cookies found in Redis")
        {:error, :no_cookies}

      {:ok, cookies} ->
        {:ok, cookies}

      error ->
        Logger.error("Failed to get cookies from Redis: #{inspect(error)}")
        error
    end
  end

  defp get_session_cookies(session_id) do
    case RedisStore.get_session_cookies(session_id) do
      {:ok, nil} ->
        Logger.warning("No cookies for session #{session_id}")
        {:error, :no_cookies}

      {:ok, cookies} ->
        {:ok, cookies}

      error ->
        Logger.error("Failed to get cookies for session #{session_id}: #{inspect(error)}")
        error
    end
  end

  defp validar_adquiriente(numero, tipo, cookies) do
    url =
      "#{SunatEndpoints.api_base_url()}?action=validarAdquiriente&tipoDocumento=#{tipo}&numeroDocumento=#{numero}"

    Logger.debug("SUNAT request: validarAdquiriente tipo=#{tipo} numero=#{numero}")

    case Req.get(url, headers: headers(cookies), decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        Logger.debug("SUNAT response: 200 OK, size=#{human_size(byte_size(body))}")
        parse_response(body)

      {:ok, %{status: status}} ->
        Logger.warning("SUNAT response: HTTP #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("SUNAT request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_domicilios(cookies) do
    url = "#{SunatEndpoints.api_base_url()}?action=getDomiciliosCliente"
    Logger.debug("SUNAT request: getDomiciliosCliente")

    case Req.get(url, headers: headers(cookies), decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        Logger.debug("SUNAT response: 200 OK, size=#{human_size(byte_size(body))}")

        with {:ok, utf8} <- to_utf8(body),
             {:ok, %{"items" => items}} <- Jason.decode(utf8) do
          Logger.debug("getDomicilios: found #{length(items)} items")
          {:ok, items}
        end

      {:ok, %{status: status}} ->
        Logger.warning("SUNAT getDomicilios response: HTTP #{status}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("SUNAT getDomicilios failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp headers(cookies) do
    [
      {"Cookie", cookies},
      {"Accept", "*/*"},
      {"X-Requested-With", "XMLHttpRequest"}
    ]
  end

  defp parse_response(body) do
    with {:ok, utf8} <- to_utf8(body),
         {:ok, %{"codeError" => 0, "data" => value}} <- Jason.decode(utf8) do
      {:ok, String.trim(value)}
    else
      {:ok, %{"messageError" => msg}} ->
        {:error, msg}

      {:ok, %{"Error" => %{"mensajeerror" => msg}}} ->
        {:error, {:session_expired, msg}}

      {:error, _} = err ->
        err

      other ->
        Logger.warning("Respuesta inesperada de SUNAT: #{inspect(other)}")
        {:error, :unknown_response}
    end
  end

  defp to_utf8(body) do
    case :unicode.characters_to_binary(body, :latin1, :utf8) do
      result when is_binary(result) -> {:ok, result}
      {:error, _, _} -> {:error, :encoding_failed}
      {:incomplete, _, _} -> {:error, :encoding_incomplete}
    end
  end

  defp human_size(bytes) when bytes < 1024, do: "#{bytes}B"
  defp human_size(bytes), do: "#{Float.round(bytes / 1024, 1)}KB"
end
