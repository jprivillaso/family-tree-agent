defmodule FamilyTreeAgent.AI.FileProcessor do
  @moduledoc """
  Processes files and documents for AI/RAG systems.

  Handles loading family data from JSON files and splitting
  documents into chunks for vector embeddings using TextChunker.
  """

  @context_file_path Path.join([
                       :code.priv_dir(:family_tree_agent),
                       "family_data",
                       "context.json"
                     ])

  @spec load_documents!(String.t()) :: list(String.t())
  def load_documents!(file_path \\ @context_file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, %{"family_members" => family_members}} ->
            Enum.map(family_members, fn member ->
              Jason.encode!(member)
            end)

          {:error, reason} ->
            raise "Failed to parse JSON: #{inspect(reason)}"
        end

      {:error, reason} ->
        raise "Failed to read file: #{inspect(reason)}"
    end
  end
end
