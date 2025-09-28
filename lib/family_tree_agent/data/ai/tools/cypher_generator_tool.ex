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
      Properties: name (string), birth_date (date), death_date (date), bio (string), occupation (string), location (string)

    Relationship Types (Keep it Simple):
    - PARENT_OF: Connects a parent to their child (directional: parent -> child)
    - MARRIED_TO: Connects spouses (bidirectional)

    Smart Query Patterns (Derive Complex Relationships from Basic Ones):

    For all the examples below, update the names to the ones you need.

    1. Find a person by name (exact match):
       MATCH (p:Person {name: "Juan Pablo Rivillas Ospina"}) RETURN p

    2. Find a person by name (partial match):
       MATCH (p:Person) WHERE p.name CONTAINS "Juan Pablo" RETURN p

    3. Find all children of a person:
       MATCH (parent:Person {name: "Juan Pablo Rivillas Ospina"})-[:PARENT_OF]->(child:Person) RETURN child

    4. Find parents of a person:
       MATCH (parent:Person)-[:PARENT_OF]->(child:Person {name: "Joao Rivillas de Magalhaes"}) RETURN parent

    5. Find spouse of a person:
       MATCH (p1:Person {name: "Juan Pablo Rivillas Ospina"})-[:MARRIED_TO]-(p2:Person) RETURN p2

    6. Find siblings (children of same parents):
       MATCH (person:Person {name: "David Rivillas de Magalhaes"})<-[:PARENT_OF]-(parent:Person)-[:PARENT_OF]->(sibling:Person)
       WHERE sibling <> person
       RETURN DISTINCT sibling.name

    7. Find grandparents (parents of parents):
       MATCH (grandparent:Person)-[:PARENT_OF*2]->(grandchild:Person {name: "Joao Rivillas de Magalhaes"})
       RETURN grandparent

    8. Find grandchildren (children of children):
       MATCH (grandparent:Person {name: "Cleolice Magalhaes de Souza Lima"})-[:PARENT_OF*2]->(grandchild:Person)
       RETURN grandchild

    9. Find ALL ancestors (recursive up the family tree):
       MATCH (ancestor:Person)-[:PARENT_OF*1..10]->(descendant:Person {name: "David Rivillas de Magalhaes"})
       RETURN ancestor, length(()-[:PARENT_OF*]->(descendant)) as generation_distance
       ORDER BY generation_distance

    10. Find ALL descendants (recursive down the family tree):
        MATCH (ancestor:Person {name: "Juan Pablo Rivillas Ospina"})-[:PARENT_OF*1..10]->(descendant:Person)
        RETURN descendant, length((ancestor)-[:PARENT_OF*]->(descendant)) as generation_distance
        ORDER BY generation_distance

    11. Find uncles/aunts (siblings of parents):
        MATCH (person:Person {name: "Joao Rivillas de Magalhaes"})<-[:PARENT_OF]-(parent:Person)
        MATCH (parent)<-[:PARENT_OF]-(grandparent:Person)
        MATCH (grandparent)-[:PARENT_OF]->(uncle_aunt:Person)
        WHERE uncle_aunt <> parent
        RETURN DISTINCT uncle_aunt

    12. Find cousins (children of uncles/aunts):
        MATCH (person:Person {name: "Joao Rivillas de Magalhaes"})<-[:PARENT_OF]-(parent:Person)
        MATCH (parent)<-[:PARENT_OF]-(grandparent:Person)
        MATCH (grandparent)-[:PARENT_OF]->(uncle_aunt:Person)
        MATCH (uncle_aunt)-[:PARENT_OF]->(cousin:Person)
        WHERE uncle_aunt <> parent
        RETURN DISTINCT cousin

    13. Find relationship path between two people (CRITICAL - use EXACTLY this format):
        MATCH path = shortestPath((p1:Person {name: "Joao Rivillas de Magalhaes"})-[*1..6]-(p2:Person {name: "David Rivillas de Magalhaes"}))
        RETURN path, [r in relationships(path) | type(r)] as relationship_types, length(path) as path_length

    13b. Alternative relationship path query (CRITICAL - use EXACTLY this format):
        MATCH path = shortestPath((p1:Person {name: "Cleolice Magalhaes de Souza Lima"})-[*1..4]-(p2:Person {name: "Joao Rivillas de Magalhaes"}))
        RETURN nodes(path) as people, relationships(path) as rels, [r in relationships(path) | type(r)] as rel_types

    14. Find in-laws (spouse's family):
        MATCH (person:Person {name: "Juan Pablo Rivillas Ospina"})-[:MARRIED_TO]-(spouse:Person)
        MATCH (spouse)<-[:PARENT_OF]-(in_law:Person)
        RETURN in_law as parent_in_law

    15. Find family members by location:
        MATCH (p:Person) WHERE p.location CONTAINS "Brazil" RETURN p

    16. Find family members by occupation:
        MATCH (p:Person) WHERE p.occupation = "Lawyer" RETURN p

    Advanced Patterns:
    - Use variable-length paths [:PARENT_OF*1..10] for recursive queries
    - Use OPTIONAL MATCH for relationships that might not exist
    - Use UNION to combine multiple relationship patterns
    - Use collect() and DISTINCT to group related results
    - Use length() to calculate relationship distance
    - Use ORDER BY to sort by generation distance

    Important Notes:
    - Use exact name matching when the full name is provided in the query
    - Use CONTAINS for partial name matching
    - For complex relationships, think in terms of path traversal through PARENT_OF and MARRIED_TO
    - Always include DISTINCT when using path queries to avoid duplicates
    - Limit results to 20 items maximum using LIMIT 20
    - Use variable-length relationships (*1..10) for recursive ancestor/descendant queries
    """
  end

  defp build_cypher_prompt(schema_context, natural_language_query) do
    """
    You are an Expert Cypher query generator for a Neo4J family tree database.

    #{schema_context}

    Instructions:
    1. Convert the natural language query to a valid Cypher query
    2. Return ONLY the Cypher query, no explanations or markdown
    3. Use proper Cypher syntax
    4. CRITICAL: Extract the EXACT person name from the natural language query and use it in your Cypher query
    5. For relationship queries, use smart path traversal patterns from the examples above
    6. For "ancestors" queries, use recursive patterns like [:PARENT_OF*1..10] to go up the family tree
    7. For "descendants" queries, use recursive patterns to go down the family tree
    8. For "siblings" queries, find shared parents using the pattern shown in example 6 - MAKE SURE to use the person name from the question
    9. For "relationship between X and Y" queries, ALWAYS use shortestPath (spelled correctly!) with the exact pattern from example 13 or 13b
    10. Use exact name matching when full names are provided in the question
    11. Use CONTAINS for partial name matching when only partial names are provided
    12. Always include DISTINCT when using path queries to avoid duplicates
    13. Return relevant properties (name, birth_date, death_date, bio, occupation, location)
    14. Limit results to 20 items maximum using LIMIT 20
    15. DOUBLE-CHECK: Make sure the person name in your Cypher query matches the person name mentioned in the natural language question

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
    # Fix common typos
    |> String.replace("shortesstPath", "shortestPath")
    |> String.replace("shorttestPath", "shortestPath")
    |> String.replace("shortesPath", "shortestPath")
    # Fix missing closing parenthesis in sibling queries
    |> fix_sibling_query_syntax()
  end

  defp fix_sibling_query_syntax(query) do
    # Fix pattern: {name: "Name"}<-[:PARENT_OF] should be {name: "Name"})<-[:PARENT_OF]
    query
    |> String.replace(~r/\{name:\s*"([^"]+)"\}<-\[:PARENT_OF\]/, "{name: \"\\1\"})<-[:PARENT_OF]")
  end
end
