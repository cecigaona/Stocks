import Config

config :operations_service, ecto_repos: [OperationsService.Repo]

config :operations_service, OperationsService.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", "postgres"),
  hostname: System.get_env("DB_HOST", "postgres"),
  database: System.get_env("DB_NAME", "operations_db"),
  port: String.to_integer(System.get_env("DB_PORT", "5432")),
  pool_size: 10

config :operations_service, OperationsServiceWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4003"))],
  server: true,
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "dev_only_secret_key_base_please_override_1234567890abcdefghijklmnopqrstuvwxyz"
    ),
  render_errors: [formats: [json: OperationsServiceWeb.ErrorJSON], layout: false],
  check_origin: false

config :phoenix, :json_library, Jason
