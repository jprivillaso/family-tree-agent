defmodule FamilyTreeAgent.Data.Neo4jSeeder do
  @moduledoc """
  Seeder module for populating Neo4J database with family tree data.

  This module reads family data from JSON files and creates the appropriate
  nodes and relationships in Neo4J using Cypher queries.
  """

  alias FamilyTreeAgent.Data.Neo4j

  require Logger

  @family_data_path "priv/family_data/context.json"

  @doc """
  Seed the Neo4J database with family tree data.
  This will clear existing data and create fresh nodes and relationships.
  """
  def seed_database do
    Logger.info("🌱 Starting Neo4J database seeding...")

    with {:ok, family_data} <- load_family_data(),
         :ok <- clear_database(),
         :ok <- create_constraints(),
         :ok <- create_family_members(family_data),
         :ok <- create_relationships(family_data) do
      Logger.info("✅ Neo4J database seeding completed successfully!")
      :ok
    else
      {:error, reason} ->
        Logger.error("❌ Neo4J database seeding failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Load and validate family data from JSON file.
  """
  def load_family_data do
    case File.read(@family_data_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"family_members" => members}} when is_list(members) ->
            Logger.info("📖 Loaded #{length(members)} family members from #{@family_data_path}")
            {:ok, members}

          {:ok, _} ->
            {:error, "Invalid JSON structure - expected 'family_members' array"}

          {:error, reason} ->
            {:error, "Failed to parse JSON: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read family data file: #{reason}"}
    end
  end

  @doc """
  Clear all existing data from the database.
  """
  def clear_database do
    Logger.info("🧹 Clearing existing Neo4J data...")

    cypher = "MATCH (n) DETACH DELETE n"

    case Neo4j.execute_cypher(cypher) do
      {:ok, _response} ->
        Logger.info("✅ Database cleared successfully")
        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to clear database: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Create database constraints for better performance and data integrity.
  """
  def create_constraints do
    Logger.info("🔧 Creating database constraints...")

    constraints = [
      "CREATE CONSTRAINT person_name_unique IF NOT EXISTS FOR (p:Person) REQUIRE p.name IS UNIQUE"
    ]

    Enum.reduce_while(constraints, :ok, fn constraint, _acc ->
      case Neo4j.execute_cypher(constraint) do
        {:ok, _response} ->
          {:cont, :ok}

        {:error, reason} ->
          # Constraints might already exist, so we'll log but continue
          Logger.info("Constraint creation result: #{reason}")
          {:cont, :ok}
      end
    end)
  end

  @doc """
  Create Person nodes for all family members.
  """
  def create_family_members(family_members) do
    Logger.info("👥 Creating #{length(family_members)} Person nodes...")

    Enum.reduce_while(family_members, :ok, fn member, _acc ->
      case create_person_node(member) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Create relationships between family members.
  """
  def create_relationships(family_members) do
    Logger.info("🔗 Creating family relationships...")

    Enum.reduce_while(family_members, :ok, fn member, _acc ->
      case create_member_relationships(member) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Private functions

  defp create_person_node(member) do
    name = Map.get(member, "name")
    birth_date = Map.get(member, "birth_date")
    death_date = Map.get(member, "death_date")
    bio = Map.get(member, "bio", "")

    # Extract metadata
    metadata = Map.get(member, "metadata", %{})
    occupation = Map.get(metadata, "occupation", "")
    location = Map.get(metadata, "location", "")

    # Build properties map
    properties = %{
      name: name,
      birth_date: birth_date,
      bio: bio,
      occupation: occupation,
      location: location
    }

    # Add death_date only if it exists
    properties = if death_date, do: Map.put(properties, :death_date, death_date), else: properties

    # Convert properties to Cypher format
    props_string =
      properties
      |> Enum.map(fn {key, value} -> "#{key}: $#{key}" end)
      |> Enum.join(", ")

    cypher = "CREATE (p:Person {#{props_string}})"

    case Neo4j.execute_cypher(cypher, properties) do
      {:ok, _response} ->
        Logger.debug("✅ Created Person node for: #{name}")
        :ok

      {:error, reason} ->
        Logger.error("❌ Failed to create Person node for #{name}: #{reason}")
        {:error, reason}
    end
  end

  defp create_member_relationships(member) do
    name = Map.get(member, "name")
    relationships = Map.get(member, "relationships", %{})

    # Create parent relationships
    case create_parent_relationships(name, relationships) do
      :ok -> create_spouse_relationships(name, relationships)
      error -> error
    end
  end

  defp create_parent_relationships(child_name, relationships) do
    parents = Map.get(relationships, "parents", [])

    Enum.reduce_while(parents, :ok, fn parent_name, _acc ->
      case create_parent_child_relationship(parent_name, child_name) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp create_spouse_relationships(person_name, relationships) do
    case Map.get(relationships, "spouse") do
      nil -> :ok
      spouse_name -> create_marriage_relationship(person_name, spouse_name)
    end
  end

  defp create_parent_child_relationship(parent_name, child_name) do
    cypher = """
    MATCH (parent:Person {name: $parent_name})
    MATCH (child:Person {name: $child_name})
    CREATE (parent)-[:PARENT_OF]->(child)
    """

    params = %{parent_name: parent_name, child_name: child_name}

    case Neo4j.execute_cypher(cypher, params) do
      {:ok, _response} ->
        Logger.debug("✅ Created PARENT_OF relationship: #{parent_name} -> #{child_name}")
        :ok

      {:error, reason} ->
        Logger.error(
          "❌ Failed to create PARENT_OF relationship #{parent_name} -> #{child_name}: #{reason}"
        )

        {:error, reason}
    end
  end

  defp create_marriage_relationship(person1_name, person2_name) do
    # Check if relationship already exists to avoid duplicates
    check_cypher = """
    MATCH (p1:Person {name: $person1_name})
    MATCH (p2:Person {name: $person2_name})
    RETURN EXISTS((p1)-[:MARRIED_TO]-(p2)) AS exists
    """

    check_params = %{person1_name: person1_name, person2_name: person2_name}

    case Neo4j.execute_cypher(check_cypher, check_params) do
      {:ok, response} ->
        # Parse response to check if relationship exists
        exists = parse_relationship_exists(response)

        if exists do
          Logger.debug(
            "⚠️  MARRIED_TO relationship already exists: #{person1_name} <-> #{person2_name}"
          )

          :ok
        else
          create_marriage_relationship_internal(person1_name, person2_name)
        end

      {:error, reason} ->
        Logger.error("❌ Failed to check existing marriage relationship: #{reason}")
        {:error, reason}
    end
  end

  defp create_marriage_relationship_internal(person1_name, person2_name) do
    cypher = """
    MATCH (p1:Person {name: $person1_name})
    MATCH (p2:Person {name: $person2_name})
    CREATE (p1)-[:MARRIED_TO]->(p2)
    CREATE (p2)-[:MARRIED_TO]->(p1)
    """

    params = %{person1_name: person1_name, person2_name: person2_name}

    case Neo4j.execute_cypher(cypher, params) do
      {:ok, _response} ->
        Logger.debug("✅ Created MARRIED_TO relationship: #{person1_name} <-> #{person2_name}")
        :ok

      {:error, reason} ->
        Logger.error(
          "❌ Failed to create MARRIED_TO relationship #{person1_name} <-> #{person2_name}: #{reason}"
        )

        {:error, reason}
    end
  end

  defp parse_relationship_exists(%{"results" => results}) when is_list(results) do
    case results do
      [%{"data" => [%{"row" => [exists]}]} | _] -> exists
      _ -> false
    end
  end

  defp parse_relationship_exists(_), do: false

  @doc """
  Verify the seeded data by running some basic queries.
  """
  def verify_seeded_data do
    Logger.info("🔍 Verifying seeded data...")

    queries = [
      {"Total Person nodes", "MATCH (p:Person) RETURN count(p) AS count"},
      {"Total PARENT_OF relationships", "MATCH ()-[r:PARENT_OF]->() RETURN count(r) AS count"},
      {"Total MARRIED_TO relationships", "MATCH ()-[r:MARRIED_TO]->() RETURN count(r) AS count"},
      {"Sample Person with relationships",
       "MATCH (p:Person {name: 'Juan Pablo Rivillas Ospina'}) RETURN p LIMIT 1"}
    ]

    Enum.each(queries, fn {description, cypher} ->
      case Neo4j.execute_cypher(cypher) do
        {:ok, response} ->
          Logger.info("✅ #{description}: #{inspect(response, pretty: true)}")

        {:error, reason} ->
          Logger.error("❌ Failed to verify #{description}: #{reason}")
      end
    end)
  end
end
