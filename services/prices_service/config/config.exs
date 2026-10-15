import Config

config :prices_service, ecto_repos: [PricesService.Repo]

config :prices_service, PricesService.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "postgres"),
  database: System.get_env("DB_NAME", "prices_db"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  pool_size: 10

config :prices_service, PricesServiceWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4002"))],
  server: true,
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "dev_only_secret_key_base_please_override_1234567890abcdefghijklmnopqrstuvwxyz"
    ),
  render_errors: [formats: [json: PricesServiceWeb.ErrorJSON], layout: false],
  check_origin: false

config :phoenix, :json_library, Jason

config :prices_service, :consul,
  enabled: false,
  host: "localhost",
  port: 8500,
  service_name: "prices_service",
  service_address: "localhost",
  service_port: 4002,
  tags: ["backend", "stocks", "prices"],
  health_path: "/health",
  health_interval: "10s",
  health_timeout: "3s",
  deregister_critical_service_after: "30s",
  cache_ttl_ms: 3000
