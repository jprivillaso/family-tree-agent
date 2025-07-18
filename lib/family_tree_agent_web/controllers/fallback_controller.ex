defmodule FamilyTreeAgentWeb.FallbackController do
  use FamilyTreeAgentWeb, :controller

  @doc """
  Handles generic errors that don't match specific patterns.
  """
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{
      success: false,
      error: %{
        message: "Resource not found",
        details: "The requested resource could not be found"
      }
    })
  end

  def call(conn, {:error, errors}) when is_list(errors) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      success: false,
      error: %{
        message: "Validation failed",
        details: errors
      }
    })
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      success: false,
      error: %{
        message: "Internal server error",
        details: inspect(reason)
      }
    })
  end
end
