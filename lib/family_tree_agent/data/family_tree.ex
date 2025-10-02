defmodule FamilyTreeAgent.Data.FamilyTree do
  @moduledoc """
  Data layer for family tree operations using Neo4j GraphRAG database.

  This module handles all the business logic for fetching and formatting
  family tree data, keeping controllers clean and focused on HTTP concerns.
  """

  alias FamilyTreeAgent.Data.Neo4j

  require Logger

  @doc """
  Fetches all family members with their relationships (children and spouse).
  Returns a comprehensive structure suitable for building family trees in the frontend.
  """
  @spec get_all_members() :: {:ok, list(map())} | {:error, String.t()}
  def get_all_members do
    Logger.info("Fetching all family members from Neo4j")

    cypher_query = """
    MATCH (p:Person)
    OPTIONAL MATCH (p)-[:PARENT_OF]->(child:Person)
    OPTIONAL MATCH (p)-[:MARRIED_TO]-(spouse:Person)
    RETURN p.name as name,
           p.birth_date as birth_date,
           p.death_date as death_date,
           p.bio as bio,
           p.occupation as occupation,
           p.location as location,
           collect(DISTINCT child.name) as children,
           spouse.name as spouse
    ORDER BY p.name
    """

    case Neo4j.execute_cypher(cypher_query) do
      {:ok, response} ->
        family_members = format_neo4j_response(response)
        {:ok, family_members}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp format_neo4j_response(%{"results" => results}) when is_list(results) do
    results
    |> Enum.flat_map(fn result ->
      case result do
        %{"columns" => columns, "data" => data} when is_list(columns) and is_list(data) ->
          Enum.map(data, fn row_data ->
            format_family_member_row(row_data, columns)
          end)

        _ ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp format_neo4j_response(_response) do
    Logger.warning("Unexpected Neo4j response format")
    []
  end

  defp format_family_member_row(%{"row" => row}, columns) when is_list(row) and is_list(columns) do
    columns
    |> Enum.zip(row)
    |> Enum.into(%{})
    |> clean_family_member_data()
  end

  defp format_family_member_row(row_data, _columns) do
    Logger.warning("Unexpected row data format: #{inspect(row_data)}")
    nil
  end

  defp clean_family_member_data(member_data) do
    %{
      name: get_string_value(member_data, "name"),
      birth_date: get_string_value(member_data, "birth_date"),
      death_date: get_string_value(member_data, "death_date"),
      biography: get_string_value(member_data, "bio"),
      occupation: get_string_value(member_data, "occupation"),
      location: get_string_value(member_data, "location"),
      children: clean_list_value(member_data, "children"),
      spouse: get_string_value(member_data, "spouse")
    }
    |> remove_nil_values()
  end

  defp get_string_value(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp clean_list_value(map, key) do
    case Map.get(map, key) do
      list when is_list(list) ->
        Enum.reject(list, &is_nil/1)
      _ -> []
    end
  end

  defp remove_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
end
