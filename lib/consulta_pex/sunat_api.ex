defmodule ConsultaPex.SunatApi do
  @base_url "https://ww1.sunat.gob.pe/ol-ti-itemisionboleta/emitir.do"

  require Logger
  alias ConsultaPex.RedisStore

  # DNI → retorna nombre
  def consultar_dni(dni) do
    with {:ok, cookies} <- get_cookies(),
         {:ok, nombre} <- validar_adquiriente(dni, 1, cookies) do
      {:ok, %{nombre: nombre}}
    end
  end

  # RUC → retorna razón social + domicilios
  def consultar_ruc(ruc) do
    with {:ok, cookies} <- get_cookies(),
         {:ok, razon_social} <- validar_adquiriente(ruc, 6, cookies),
         {:ok, domicilios} <- get_domicilios(cookies) do
      {:ok, %{razon_social: razon_social, domicilios: domicilios}}
    end
  end

  defp get_cookies do
    case RedisStore.get_cookies() do
      {:ok, nil} -> {:error, :no_cookies}
      {:ok, cookies} -> {:ok, cookies}
      error -> error
    end
  end

  defp validar_adquiriente(numero, tipo, cookies) do
    url = "#{@base_url}?action=validarAdquiriente&tipoDocumento=#{tipo}&numeroDocumento=#{numero}"

    case Req.get(url, headers: headers(cookies), decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        parse_response(body)

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_domicilios(cookies) do
    url = "#{@base_url}?action=getDomiciliosCliente"

    case Req.get(url, headers: headers(cookies), decode_body: false) do
      {:ok, %{status: 200, body: body}} ->
        with {:ok, utf8} <- to_utf8(body),
             {:ok, %{"items" => items}} <- Jason.decode(utf8) do
          {:ok, items}
        end

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
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
end
