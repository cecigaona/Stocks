import Config

config :exchanges_service, ecto_repos: [ExchangesService.Repo]

config :exchanges_service, ExchangesService.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "postgres"),
  database: System.get_env("DB_NAME", "exchanges_db"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  pool_size: 10

config :exchanges_service, ExchangesServiceWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4001"))],
  server: true,
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "dev_only_secret_key_base_please_override_1234567890abcdefghijklmnopqrstuvwxyz"
    ),
  render_errors: [formats: [json: ExchangesServiceWeb.ErrorJSON], layout: false],
  check_origin: false

config :phoenix, :json_library, Jason

config :exchanges_service, :consul,
  enabled: false,
  host: "localhost",
  port: 8500,
  service_name: "exchanges_service",
  service_address: "localhost",
  service_port: 4001,
  tags: ["backend", "stocks"],
  health_path: "/health",
  health_interval: "10s",
  health_timeout: "3s",
  deregister_critical_service_after: "30s",
  cache_ttl_ms: 3000
