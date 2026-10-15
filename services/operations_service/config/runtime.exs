import Config

if config_env() != :test do
  db_user = System.get_env("DB_USER", "postgres")
  db_password = System.get_env("DB_PASSWORD", "postgres")
  db_host = System.get_env("DB_HOST", "postgres")
  db_name = System.get_env("DB_NAME", "operations_db")
  db_port = String.to_integer(System.get_env("DB_PORT", "5432"))

  config :operations_service, OperationsService.Repo,
    username: db_user,
    password: db_password,
    hostname: db_host,
    database: db_name,
    port: db_port,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  port = String.to_integer(System.get_env("PORT", "4003"))

  config :operations_service, OperationsServiceWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    server: true,
    secret_key_base:
      System.get_env(
        "SECRET_KEY_BASE",
        "dev_only_secret_key_base_please_override_1234567890abcdefghijklmnopqrstuvwxyz"
      )

  consul_host = System.get_env("CONSUL_HOST", "consul")
  consul_port = String.to_integer(System.get_env("CONSUL_PORT", "8500"))
  service_name = System.get_env("SERVICE_NAME", "operations_service")
  service_address = System.get_env("SERVICE_ADDRESS", service_name)

  tags =
    System.get_env("SERVICE_TAGS", "backend,stocks,operations")
    |> String.split(",", trim: true)

  health_interval = System.get_env("CONSUL_HEALTH_INTERVAL", "10s")
  health_timeout = System.get_env("CONSUL_HEALTH_TIMEOUT", "3s")
  deregister_after = System.get_env("CONSUL_DEREGISTER_AFTER", "30s")
  cache_ttl_ms = String.to_integer(System.get_env("CONSUL_CACHE_TTL_MS", "3000"))

  config :operations_service, :consul,
    enabled: System.get_env("CONSUL_ENABLED", "true") == "true",
    host: consul_host,
    port: consul_port,
    service_name: service_name,
    service_address: service_address,
    service_port: port,
    tags: tags,
    health_path: "/health",
    health_interval: health_interval,
    health_timeout: health_timeout,
    deregister_critical_service_after: deregister_after,
    cache_ttl_ms: cache_ttl_ms
end
