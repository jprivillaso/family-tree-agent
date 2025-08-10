defmodule FamilyTreeAgent.AI.FileProcessor do
  @chunk_size 200
  @chunk_overlap 20
  @context_file_path Path.join([:code.priv_dir(:family_tree_agent), "family_data", "context.txt"])

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

  @spec split_documents(list(String.t())) :: list(String.t())
  def split_documents(documents) do
    Enum.flat_map(documents, fn doc ->
      split_text_into_chunks(doc, @chunk_size, @chunk_overlap)
    end)
  end

  defp split_text_into_chunks(text, chunk_size, chunk_overlap) do
    words = String.split(text, ~r/\s+/)

    if length(words) <= chunk_size do
      [text]
    else
      chunk_words(words, chunk_size, chunk_overlap, [])
    end
  end

  defp chunk_words([], _chunk_size, _overlap, acc), do: Enum.reverse(acc)

  defp chunk_words(words, chunk_size, _overlap, acc) when length(words) <= chunk_size do
    chunk = Enum.join(words, " ")
    Enum.reverse([chunk | acc])
  end

  defp chunk_words(words, chunk_size, overlap, acc) do
    {chunk_words, _remaining_words} = Enum.split(words, chunk_size)
    chunk = Enum.join(chunk_words, " ")

    # Calculate overlap for next chunk
    overlap_size = min(overlap, chunk_size)
    next_words = Enum.drop(words, chunk_size - overlap_size)

    chunk_words(next_words, chunk_size, overlap, [chunk | acc])
  end
end
