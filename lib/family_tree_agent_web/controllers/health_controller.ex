defmodule FamilyTreeAgentWeb.HealthController do
  @moduledoc """
  Controller for health checks and system status.
  """

  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.RAGServer
  alias FamilyTreeAgent.Data.Neo4j
  alias FamilyTreeAgent.AI.Clients.Client, as: AIClient
  alias FamilyTreeAgent.AI.Clients.Ollama
  alias FamilyTreeAgent.AI.Clients.OpenAI

  require Logger

  @spec health(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @doc """
  GET /api/health
  Returns the health status of the application and its components.
  """
  def health(conn, _params) do
    Logger.info("Health check requested")

    # Check all components
    neo4j_status = get_neo4j_status()
    ai_client_status = get_ai_client_status()
    rag_status = get_rag_status()

    components = %{
      neo4j: neo4j_status,
      ai_client: ai_client_status,
      rag_system: rag_status
    }

    # Determine overall status
    overall_status = determine_overall_status(components)

    response = %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      components: components,
      version: Application.spec(:family_tree_agent, :vsn) |> to_string()
    }

    # Return 200 for healthy, 503 for unhealthy
    status_code = if overall_status == "healthy", do: :ok, else: :service_unavailable

    conn
    |> put_status(status_code)
    |> json(response)
  end

  defp get_neo4j_status do
    case Neo4j.test_connection() do
      {:ok, _} ->
        %{
          status: "healthy",
          message: "Neo4j is running and accessible",
          url: "http://localhost:7474"
        }

      {:error, reason} ->
        %{
          status: "unhealthy",
          message: "Neo4j connection failed",
          error: inspect(reason),
          url: "http://localhost:7474",
          help: "Ensure Neo4j is running with credentials neo4j:familytree123"
        }
    end
  end

  defp get_ai_client_status do
    client_type = AIClient.get_configured_client_type()

    case client_type do
      :ollama -> get_ollama_status()
      :openai -> get_openai_status()
      _ -> %{status: "unknown", message: "Unknown AI client type: #{client_type}"}
    end
  end

  defp get_ollama_status do
    try do
      # Create a temporary Ollama client to test connection
      case Ollama.init() do
        {:ok, _client} ->
          %{
            status: "healthy",
            message: "Ollama is running",
            url: "http://localhost:11434",
          }

        {:error, reason} ->
          %{
            status: "unhealthy",
            message: "Ollama connection failed",
            error: inspect(reason),
            url: "http://localhost:11434",
            help: "Ensure Ollama is running on localhost:11434"
          }
      end
    rescue
      error ->
        %{
          status: "unhealthy",
          message: "Ollama health check failed",
          error: Exception.message(error),
          url: "http://localhost:11434"
        }
    end
  end

  defp get_openai_status do
    try do
      # Create a temporary OpenAI client to test connection
      case OpenAI.init() do
        {:ok, client} ->
          %{
            status: "healthy",
            message: "OpenAI is running",
            provider: "OpenAI",
            embedding_model: client.embedding_model,
            chat_model: client.chat_model
          }

        {:error, reason} ->
          %{
            status: "unhealthy",
            message: "OpenAI connection failed",
            error: inspect(reason),
            provider: "OpenAI",
            help: "Check OPENAI_API_KEY environment variable"
          }
      end
    rescue
      error ->
        %{
          status: "unhealthy",
          message: "OpenAI connection failed",
          error: Exception.message(error),
          provider: "OpenAI",
          help: "Verify API key and network connectivity"
        }
    end
  end

  defp get_rag_status do
    try do
      state = RAGServer.get_state()

      case state do
        %{status: :ready} ->
          %{status: "healthy", message: "RAG system is operational"}

        %{status: :degraded, error: error} ->
          %{status: "degraded", message: "RAG system failed to initialize", error: error}

        _ ->
          %{status: "unknown", message: "RAG system status unknown"}
      end
    rescue
      _ ->
        %{status: "unavailable", message: "RAG server is not responding"}
    end
  end

  defp determine_overall_status(components) do
    statuses =
      components
      |> Map.values()
      |> Enum.map(fn component -> component.status end)

    cond do
      Enum.all?(statuses, &(&1 == "healthy")) -> "healthy"
      Enum.any?(statuses, &(&1 in ["unhealthy", "unavailable"])) -> "unhealthy"
      true -> "degraded"
    end
  end
end
