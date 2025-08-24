defmodule FamilyTreeAgent.AI.Tools.CypherGeneratorTool do
  @moduledoc """
  Tool for converting natural language queries into valid Cypher queries
  for family tree data stored in Neo4J.
  """

  alias FamilyTreeAgent.AI.Clients.Ollama, as: OllamaClient

  @type t :: %__MODULE__{
          ai_client: any(),
          schema_context: String.t()
        }

  defstruct [
    :ai_client,
    :schema_context
  ]

  @doc """
  Initialize the Cypher generator tool with an AI client.
  """
  def init(ai_client) do
    schema_context = build_schema_context()

    %__MODULE__{
      ai_client: ai_client,
      schema_context: schema_context
    }
  end

  @doc """
  Convert a natural language query to a Cypher query.
  """
  def generate_cypher(%__MODULE__{} = tool, natural_language_query) do
    prompt = build_cypher_prompt(tool.schema_context, natural_language_query)

    case OllamaClient.generate_text(tool.ai_client, prompt) do
      {:ok, cypher_query} ->
        cleaned_query = clean_cypher_query(cypher_query)
        {:ok, cleaned_query}

      {:error, reason} ->
        {:error, "Failed to generate Cypher query: #{reason}"}
    end
  end

  # Private functions

  defp build_schema_context do
    """
    Neo4J Database Schema for Family Tree:

    Node Types:
    - Person: Represents a family member
      Properties: name (string), birth_date (date), death_date (date), bio (string), hobbies (string)

    Relationship Types:
    - PARENT_OF: Connects a parent to their child
    - MARRIED_TO: Connects spouses (bidirectional)

    Example Queries:
    1. Find a person by name:
       MATCH (p:Person {name: "John Doe"}) RETURN p

    2. Find all children of a person:
       MATCH (parent:Person {name: "John Doe"})-[:PARENT_OF]->(child:Person) RETURN child

    3. Find parents of a person:
       MATCH (parent:Person)-[:PARENT_OF]->(child:Person {name: "Jane Doe"}) RETURN parent

    4. Find spouse of a person:
       MATCH (p1:Person {name: "John Doe"})-[:MARRIED_TO]-(p2:Person) RETURN p2

    5. Find siblings of a person (people with same parents):
       MATCH (person:Person {name: "John Doe"})<-[:PARENT_OF]-(parent:Person)
       MATCH (parent)-[:PARENT_OF]->(sibling:Person)
       WHERE sibling <> person
       RETURN DISTINCT sibling

    6. Find all descendants of a person:
       MATCH (ancestor:Person {name: "John Doe"})-[:PARENT_OF*]->(descendant:Person) RETURN descendant

    7. Find all ancestors of a person:
       MATCH (ancestor:Person)-[:PARENT_OF*]->(descendant:Person {name: "Jane Doe"}) RETURN ancestor
    """
  end

  defp build_cypher_prompt(schema_context, natural_language_query) do
    """
    You are an Expert Cypher query generator for a Neo4J family tree database.

    #{schema_context}

    Instructions:
    1. Convert the natural language query to a valid Cypher query
    2. Return ONLY the Cypher query, no explanations
    3. Use proper Cypher syntax
    4. Handle case-insensitive name matching when appropriate
    5. Return relevant properties (name, birth_date, death_date, bio, hobbies)
    6. Limit results to 20 items maximum using LIMIT 20

    Natural Language Query: #{natural_language_query}

    Cypher Query:
    """
  end

  defp clean_cypher_query(raw_query) do
    raw_query
    |> String.trim()
    |> String.replace(~r/^```cypher\s*/, "")
    |> String.replace(~r/^```\s*/, "")
    |> String.replace(~r/```$/, "")
    |> String.trim()
  end
end
