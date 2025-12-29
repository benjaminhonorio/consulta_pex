import Config

get_env_required = fn name ->
  System.get_env(name) || raise "Missing required env var: #{name}"
end

get_env_integer = fn name, default ->
  case System.get_env(name) do
    nil ->
      default

    val ->
      case Integer.parse(val) do
        {int, ""} -> int
        _ -> raise "Invalid integer for #{name}: #{val}"
      end
  end
end

config :consulta_pex,
  ruc: get_env_required.("RUC"),
  usuario_sol: get_env_required.("USUARIO_SOL"),
  clave_sol: get_env_required.("CLAVE_SOL"),
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  http_port: get_env_integer.("PORT", 4000),
  pool_size: get_env_integer.("POOL_SIZE", 2),
  refresh_interval: get_env_integer.("REFRESH_INTERVAL", 3_600_000),
  retry_interval: get_env_integer.("RETRY_INTERVAL", 300_000)
