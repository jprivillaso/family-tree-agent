defmodule FamilyTreeAgent.AI.FamilyTreeGraphRAG do
  @moduledoc """
  Graph-based RAG system for family tree queries using Neo4J.

  This module implements a planner that uses tools to:
  1. Convert natural language queries to Cypher queries
  2. Execute those queries against Neo4J
  3. Format and return the results

  This follows the same client pattern as the existing RAG system but
  focuses on structured graph data rather than vector embeddings.
  """

  @behaviour FamilyTreeAgent.AI.Clients.PlannerBehavior

  alias FamilyTreeAgent.AI.Clients.Ollama, as: OllamaClient
  alias FamilyTreeAgent.AI.Tools.CypherGeneratorTool
  alias FamilyTreeAgent.AI.Tools.Neo4jExecutorTool

  require Logger

  @type t :: %__MODULE__{
          ai_client: any(),
          cypher_tool: CypherGeneratorTool.t(),
          neo4j_tool: Neo4jExecutorTool.t()
        }

  defstruct [
    :ai_client,
    :cypher_tool,
    :neo4j_tool
  ]

  @impl true
  def init(config \\ []) do
    Logger.info("🔧 Initializing FamilyTreeGraphRAG...")

    with {:ok, ai_client} <- OllamaClient.init(config) do
      cypher_tool = CypherGeneratorTool.init(ai_client)
      neo4j_tool = Neo4jExecutorTool.init(config)

      # Test Neo4J connection
      case Neo4jExecutorTool.test_connection(neo4j_tool) do
        {:ok, _} ->
          Logger.info("✅ Neo4J connection successful")

        {:error, reason} ->
          Logger.warning("⚠️  Neo4J connection test failed: #{reason}")
          Logger.info("Continuing initialization - queries may fail if Neo4J is not available")
      end

      %__MODULE__{
        ai_client: ai_client,
        cypher_tool: cypher_tool,
        neo4j_tool: neo4j_tool
      }
    else
      {:error, reason} ->
        Logger.error("❌ Failed to initialize FamilyTreeGraphRAG: #{reason}")
        {:error, reason}
    end
  end

  @impl true
  def execute_plan(%__MODULE__{} = graph_rag, query) do
    Logger.info("🚀 Executing plan for query: #{query}")

    with {:ok, cypher_query} <- generate_cypher_query(graph_rag, query),
         {:ok, results} <- execute_cypher_query(graph_rag, cypher_query),
         {:ok, formatted_response} <- format_final_response(graph_rag, query, results) do
      {:ok, formatted_response}
    else
      {:error, reason} ->
        Logger.error("❌ Plan execution failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Execute a one-shot query against the graph database.
  This is the main entry point for querying family tree data.
  """
  def one_shot(%__MODULE__{} = graph_rag, query) do
    case execute_plan(graph_rag, query) do
      {:ok, response} ->
        response

      {:error, reason} ->
        "❌ Query failed: #{reason}"
    end
  end

  # Private functions

  defp generate_cypher_query(%__MODULE__{} = graph_rag, natural_language_query) do
    Logger.info("🔄 Step 1: Converting natural language to Cypher query...")

    case CypherGeneratorTool.generate_cypher(graph_rag.cypher_tool, natural_language_query) do
      {:ok, cypher_query} ->
        Logger.info("✅ Generated Cypher query: #{cypher_query}")
        {:ok, cypher_query}

      {:error, reason} ->
        Logger.error("❌ Failed to generate Cypher query: #{reason}")
        {:error, reason}
    end
  end

  defp execute_cypher_query(%__MODULE__{} = graph_rag, cypher_query) do
    Logger.info("🔄 Step 2: Executing Cypher query against Neo4J...")

    case Neo4jExecutorTool.execute_query(graph_rag.neo4j_tool, cypher_query) do
      {:ok, results} ->
        IO.inspect(results, label: "results")

        Logger.info("✅ Query executed successfully, found #{length(results)} results")
        {:ok, results}

      {:error, reason} ->
        Logger.error("❌ Failed to execute Cypher query: #{reason}")
        {:error, reason}
    end
  end

  defp format_final_response(%__MODULE__{} = graph_rag, original_query, results) do
    Logger.info("🔄 Step 3: Formatting final response...")

    if Enum.empty?(results) do
      {:ok, "No results found for your query: #{original_query}"}
    else
      case generate_natural_language_response(graph_rag, original_query, results) do
        {:ok, response} ->
          Logger.info("✅ Final response generated")
          {:ok, response}

        {:error, reason} ->
          # Fallback to raw results if AI formatting fails
          Logger.warning("⚠️  AI formatting failed (#{reason}), returning raw results")
          formatted_results = format_raw_results(results)
          {:ok, "Results for '#{original_query}':\n#{formatted_results}"}
      end
    end
  end

  defp generate_natural_language_response(%__MODULE__{} = graph_rag, query, results) do
    results_text = format_results_for_ai(results)

    prompt = """
    You are a helpful assistant that answers questions about family relationships.

    Original Question: #{query}

    Database Results:
    #{results_text}

    Instructions:
    1. Answer the question in a natural, conversational way
    2. Use the information from the database results
    3. If multiple people are found, list them clearly
    4. Keep the response concise but informative
    5. If no relevant information is found, say so clearly
    6. Use the name in the map to match the person asked in the prompt

    Response:
    """

    case OllamaClient.generate_text(graph_rag.ai_client, prompt) do
      {:ok, response} ->
        {:ok, String.trim(response)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_results_for_ai(results) when is_list(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map(fn {result, index} ->
      "#{index}. #{format_single_result_for_ai(result)}"
    end)
    |> Enum.join("\n")
  end

  defp format_single_result_for_ai(result) when is_map(result) do
    case result do
      %{name: name, type: "Person"} = person ->
        base = "#{name}"

        details =
          []
          |> maybe_add_detail(person, :birth_date, "born")
          |> maybe_add_detail(person, :death_date, "died")
          |> maybe_add_detail(person, :biography, "bio")
          |> maybe_add_detail(person, :hobbies, "hobbies")

        if Enum.empty?(details) do
          base
        else
          "#{base} (#{Enum.join(details, ", ")})"
        end

      _ ->
        inspect(result)
    end
  end

  defp format_single_result_for_ai(result) do
    inspect(result)
  end

  defp maybe_add_detail(details, person, key, label) do
    case Map.get(person, key) do
      nil -> details
      "" -> details
      value -> details ++ ["#{label}: #{value}"]
    end
  end

  defp format_raw_results(results) when is_list(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map(fn {result, index} ->
      "#{index}. #{inspect(result, pretty: true)}"
    end)
    |> Enum.join("\n")
  end
end
