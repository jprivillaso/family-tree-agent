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

  alias FamilyTreeAgent.AI.ClientFactory
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

    with {:ok, ai_client} <- ClientFactory.create_client() do
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
          IO.inspect(response, label: "response")
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
    IO.inspect(results, label: "results")

    results_text = format_results_for_ai(results)

    prompt = """
    You are a helpful assistant that answers questions about family relationships.

    Original Question: #{query}

    Database Results:
    #{results_text}

    IMPORTANT INSTRUCTIONS:
    1. You MUST use ONLY the information provided in the Database Results above
    2. The Database Results contain the answer to the question - do NOT ignore this data
    3. If the Database Results show a person with a name, birth_date, and bio, then that person EXISTS in our family tree
    4. Answer the question using the provided data in a natural, conversational way
    5. Use the bio field to describe who this person is
    6. If multiple people are found, list them clearly
    7. ONLY say "no information found" if the Database Results are actually empty

    Response:
    """

    case graph_rag.ai_client.__struct__.generate_text(graph_rag.ai_client, prompt) do
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
    # Handle path query results specially
    cond do
      Map.has_key?(result, "path") and Map.has_key?(result, "relationship_types") ->
        format_path_result(result)

      true ->
        # Handle both string and atom keys from Neo4j
        name = get_value(result, ["name", :name])
        type = get_value(result, ["type", :type])

        case {name, type} do
          {name, "Person"} when is_binary(name) ->
            base = "Person name: #{name}"

            details =
              []
              |> maybe_add_detail_flexible(result, ["birth_date", :birth_date], "born")
              |> maybe_add_detail_flexible(result, ["death_date", :death_date], "died")
              |> maybe_add_detail_flexible(result, ["biography", :biography, "bio", :bio], "bio")
              |> maybe_add_detail_flexible(result, ["hobbies", :hobbies], "hobbies")

            if Enum.empty?(details) do
              base
            else
              "#{base} (#{Enum.join(details, ", ")})"
            end

          _ ->
            # Fallback: try to extract meaningful info from any map structure
            format_generic_result(result)
        end
    end
  end

  defp format_single_result_for_ai(result) do
    inspect(result)
  end

  # Format path query results (relationship between two people)
  defp format_path_result(%{"path" => path, "relationship_types" => rel_types, "path_length" => length}) do
    # Extract person names from path (skip relationship objects which are empty maps)
    people =
      path
      |> Enum.filter(fn item -> is_map(item) and Map.has_key?(item, "name") end)
      |> Enum.map(fn person -> person["name"] end)

    case {people, rel_types} do
      {[person1, person2], ["PARENT_OF"]} ->
        "#{person1} is the parent of #{person2}"

      {[person1, person2, person3], ["PARENT_OF", "PARENT_OF"]} ->
        "#{person1} is the grandparent of #{person3} (through #{person2})"

      {people_list, rel_list} when length(people_list) >= 2 ->
        first_person = List.first(people_list)
        last_person = List.last(people_list)
        rel_description = Enum.join(rel_list, " -> ")
        "#{first_person} is connected to #{last_person} through: #{rel_description} (#{length} steps)"

      _ ->
        "Relationship path found with #{length} steps: #{Enum.join(rel_types, " -> ")}"
    end
  end

  # Helper function to get value from map with multiple possible keys
  defp get_value(map, keys) when is_list(keys) do
    Enum.find_value(keys, fn key ->
      Map.get(map, key)
    end)
  end

  # Flexible version that tries multiple key formats
  defp maybe_add_detail_flexible(details, person, keys, label) when is_list(keys) do
    case get_value(person, keys) do
      nil -> details
      "" -> details
      value -> details ++ ["#{label}: #{value}"]
    end
  end

  # Format any generic result that doesn't match Person pattern
  defp format_generic_result(result) when is_map(result) do
    # Try to find a name or identifier
    name = get_value(result, ["name", :name, "title", :title, "id", :id])

    if name do
      # Build a description from available fields
      other_fields =
        result
        |> Map.drop(["name", :name, "type", :type])
        |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
        |> Enum.take(3)  # Limit to avoid too much text

      if Enum.empty?(other_fields) do
        "#{name}"
      else
        "#{name} (#{Enum.join(other_fields, ", ")})"
      end
    else
      # No clear identifier, just show key info
      result
      |> Enum.take(3)
      |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
      |> Enum.join(", ")
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
