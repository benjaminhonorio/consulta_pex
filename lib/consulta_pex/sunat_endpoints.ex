defmodule ConsultaPex.SunatEndpoints do
  @moduledoc "URLs centralizadas de SUNAT"

  def login_url do
    "https://api-seguridad.sunat.gob.pe/v1/clientessol/085b176d-2437-44cd-8c3e-e9a83b705921/oauth2/loginMenuSol?lang=es-PE&showDni=true&showLanguages=false&originalUrl=https://e-menu.sunat.gob.pe/cl-ti-itmenucabina/AutenticaMenuInternet.htm&state=rO0ABXNyABFqYXZhLnV0aWwuSGFzaE1hcAUH2sHDFmDRAwACRgAKbG9hZEZhY3RvckkACXRocmVzaG9sZHhwP0AAAAAAAAx3CAAAABAAAAADdAAEZXhlY3B0AAZwYXJhbXN0AFEqJiomL2NsLXRpLWl0bWVudWNhYmluYS9NZW51SW50ZXJuZXQuaHRtJjBlMWY4NDg5ZmVlYWJmOTMxNmI5ODUwNTYyMjA5MTE4ZjkxZTJjMmN0AANleGVweA=="
  end

  def cookie_domain, do: "https://ww1.sunat.gob.pe"

  def api_base_url, do: "https://ww1.sunat.gob.pe/ol-ti-itemisionboleta/emitir.do"
end
