import Config

config :consulta_pex,
  ruc: System.get_env("RUC") || raise("Falta RUC"),
  usuario_sol: System.get_env("USUARIO_SOL") || raise("Falta USUARIO_SOL"),
  clave_sol: System.get_env("CLAVE_SOL") || raise("Falta CLAVE_SOL"),
  redis_url: System.get_env("REDIS_URL", "redis://localhost:6379"),
  http_port: String.to_integer(System.get_env("PORT", "4000")),
  refresh_interval: String.to_integer(System.get_env("REFRESH_INTERVAL", "3600000")),
  retry_interval: String.to_integer(System.get_env("RETRY_INTERVAL", "300000"))
