defmodule FamilyTreeAgent.AI.Tools.Neo4jExecutorTool do
  @moduledoc """
  Tool for executing Cypher queries against Neo4J database
  and formatting the results for consumption.
  """

  alias FamilyTreeAgent.Data.Neo4j

  require Logger

  @type t :: %__MODULE__{
          connection_config: keyword()
        }

  defstruct [
    :connection_config
  ]

  @doc """
  Initialize the Neo4J executor tool.
  """
  def init(config \\ []) do
    %__MODULE__{
      connection_config: config
    }
  end

  @doc """
  Execute a Cypher query and return formatted results.
  """
  def execute_query(%__MODULE__{} = _tool, cypher_query) do
    Logger.info("Executing Cypher query: #{cypher_query}")

    case Neo4j.execute_cypher(cypher_query) do
      {:ok, response} ->
        formatted_results = format_neo4j_response(response)
        {:ok, formatted_results}

      {:error, reason} ->
        Logger.error("Neo4J query execution failed: #{inspect(reason)}")
        {:error, "Query execution failed: #{reason}"}
    end
  end

  @doc """
  Test the Neo4J connection.
  """
  def test_connection(%__MODULE__{} = _tool) do
    Neo4j.test_connection()
  end

  # Private functions

  defp format_neo4j_response(%{"results" => results}) when is_list(results) do
    results
    |> Enum.flat_map(fn result ->
      case result do
        %{"columns" => columns, "data" => data} when is_list(columns) and is_list(data) ->
          # Map each row to column names for proper key-value pairs
          Enum.map(data, fn row_data ->
            format_data_row_with_columns(row_data, columns)
          end)

        %{"data" => data} when is_list(data) ->
          # Fallback to old behavior if no columns
          Enum.map(data, &format_data_row/1)

        _ ->
          []
      end
    end)
  end

  defp format_neo4j_response(response) do
    Logger.info("Unexpected Neo4J response format: #{inspect(response)}")
    []
  end

  defp format_data_row_with_columns(%{"row" => row}, columns)
       when is_list(row) and is_list(columns) do
    # Zip columns with row values to create proper key-value pairs
    columns
    |> Enum.zip(row)
    |> Enum.into(%{})
    |> format_mapped_data()
  end

  defp format_data_row_with_columns(row_data, _columns) do
    Logger.warning("Unexpected row data format: #{inspect(row_data)}")
    row_data
  end

  defp format_data_row(%{"row" => row}) when is_list(row) do
    # Convert Neo4J row data to a more readable format (legacy fallback)
    row
    |> Enum.map(&format_node_or_value/1)
    |> Enum.reject(&is_nil/1)
  end

  defp format_data_row(data) do
    Logger.info("Unexpected data row format: #{inspect(data)}")
    data
  end

  defp format_mapped_data(mapped_row) when is_map(mapped_row) do
    # Clean up and format the mapped data for better LLM consumption
    formatted =
      mapped_row
      |> Enum.map(fn {key, value} ->
        {key, format_node_or_value(value)}
      end)
      |> Enum.into(%{})
      |> remove_nil_values()

    # If it's a single node column (like "p"), extract just the node data
    case Map.keys(formatted) do
      [single_key] when is_binary(single_key) ->
        case Map.get(formatted, single_key) do
          node_data when is_map(node_data) -> node_data
          _ -> formatted
        end
      _ ->
        formatted
    end
  end

  defp remove_nil_values(map) when is_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp format_node_or_value(%{"name" => name} = node) when is_map(node) do
    # This is likely a Person node
    formatted = %{
      name: name,
      type: "Person"
    }

    # Add optional properties if they exist
    formatted
    |> maybe_add_property(node, "birth_date")
    |> maybe_add_property(node, "death_date")
    |> maybe_add_property(node, "biography")
    |> maybe_add_property(node, "hobbies")
    |> maybe_add_property(node, "bio")
  end

  defp format_node_or_value(value) when is_binary(value) or is_number(value) do
    value
  end

  defp format_node_or_value(value) when is_map(value) do
    # Generic map handling
    value
  end

  defp format_node_or_value(value) do
    # Fallback for other types
    value
  end

  defp maybe_add_property(formatted, node, property_key) do
    case Map.get(node, property_key) do
      nil -> formatted
      "" -> formatted
      value -> Map.put(formatted, String.to_atom(property_key), value)
    end
  end
end
