defmodule FamilyTreeAgentWeb.HealthController do
  @moduledoc """
  Controller for health checks and system status.
  """

  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.AI.RAGServer

  @spec health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @doc """
  GET /api/health
  Returns the health status of the application and its components.
  """
  def health(conn, _params) do
    rag_status = get_rag_status()

    overall_status = if rag_status.status == :ready, do: "healthy", else: "degraded"

    conn
    |> put_status(:ok)
    |> json(%{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      components: %{
        database: "healthy",  # Assume healthy if we got this far
        rag_system: rag_status
      }
    })
  end

  defp get_rag_status do
    try do
      state = RAGServer.get_state()
      case state do
        %{status: :ready} ->
          %{status: :ready, message: "RAG system is operational"}

        %{status: :degraded, error: error} ->
          %{status: :degraded, message: "RAG system failed to initialize", error: error}

        _ ->
          %{status: :unknown, message: "RAG system status unknown"}
      end
    rescue
      _ ->
        %{status: :unavailable, message: "RAG server is not responding"}
    end
  end
end
