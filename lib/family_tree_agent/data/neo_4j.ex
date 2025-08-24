defmodule FamilyTreeAgent.Data.Neo4j do
  @moduledoc """
  HTTP-based Neo4j client using Neo4j's REST API.

  This is an alternative to the Bolt-based client that uses HTTP instead.
  """

  require Logger

  @base_url "http://localhost:7474"
  @auth_header "Basic " <> Base.encode64("neo4j:familytree123")

    @doc """
  Test the Neo4j connection via HTTP API.
  """
  def test_connection do
    try do
      # Use the root endpoint which we know works
      case Req.get("#{@base_url}/", headers: [{"Authorization", @auth_header}]) do
        {:ok, %{status: 200} = response} ->
          Logger.info("Neo4j HTTP connection test successful")
          {:ok, response.body}

        {:ok, %{status: status}} ->
          Logger.error("Neo4j HTTP connection failed with status: #{status}")
          {:error, "HTTP #{status}"}

        {:error, error} ->
          Logger.error("Neo4j HTTP connection failed: #{inspect(error)}")
          {:error, error}
      end
    rescue
      error ->
        Logger.error("Neo4j HTTP connection test failed: #{inspect(error)}")
        {:error, error}
    end
  end

    @doc """
  Execute a Cypher query via HTTP API.
  """
  def execute_cypher(query, params \\ %{}) do
    try do
      # Use Neo4j 5.x transaction endpoint
      body = %{
        "statements" => [
          %{
            "statement" => query,
            "parameters" => params
          }
        ]
      }

      case Req.post("#{@base_url}/db/neo4j/tx/commit",
                    json: body,
                    headers: [{"Authorization", @auth_header}, {"Content-Type", "application/json"}]) do
        {:ok, %{status: 200} = response} ->
          Logger.info("Cypher query executed successfully")
          {:ok, response.body}

        {:ok, %{status: status} = response} ->
          Logger.error("Cypher query failed with status: #{status}")
          {:error, "HTTP #{status}: #{inspect(response.body)}"}

        {:error, error} ->
          Logger.error("Cypher query failed: #{inspect(error)}")
          {:error, error}
      end
    rescue
      error ->
        Logger.error("Cypher query execution failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
