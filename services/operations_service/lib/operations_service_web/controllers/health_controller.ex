defmodule OperationsServiceWeb.HealthController do
  use Phoenix.Controller, formats: [:json]
  require Logger

  alias OperationsService.Repo

  def check(conn, _params) do
    case check_database() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "healthy",
          service: Application.get_env(:operations_service, :service_name, "operations_service"),
          checks: %{
            database: "passing"
          }
        })

      {:error, reason} ->
        error_msg = format_error(reason)
        Logger.error("[HealthCheck] Falla en base de datos: #{error_msg}")

        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          service: Application.get_env(:operations_service, :service_name, "operations_service"),
          checks: %{
            database: "critical"
          },
          error: error_msg
        })
    end
  end

  defp check_database do
    case Ecto.Adapters.SQL.query(Repo, "SELECT 1", [], timeout: 2000, pool_timeout: 2000) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    exception ->
      {:error, exception}
  end

  defp format_error(reason) do
    cond do
      is_exception(reason) -> Exception.message(reason)
      is_binary(reason) -> reason
      true -> inspect(reason)
    end
  end
end
