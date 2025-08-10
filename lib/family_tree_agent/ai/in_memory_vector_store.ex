defmodule FamilyTreeAgent.AI.InMemoryVectorStore do
  @moduledoc """
  A simple in-memory vector store using Nx for similarity calculations.
  This avoids the complexity of external dependencies while providing working RAG functionality.
  """

  defstruct [:documents, :embeddings]

  @doc """
  Create a new vector store with documents and their embeddings.
  """
  def new(documents_with_embeddings) do
    {documents, embeddings} = Enum.unzip(documents_with_embeddings)

    # Stack all embeddings into a single tensor for efficient batch operations
    embeddings_tensor = Nx.stack(embeddings)

    %__MODULE__{
      documents: documents,
      embeddings: embeddings_tensor
    }
  end

  @doc """
  Search for the most similar documents to a query embedding.
  """
  def similarity_search(store, query_embedding, k \\ 3) do
    # Calculate cosine similarity between query and all stored embeddings
    similarities = cosine_similarity_batch(query_embedding, store.embeddings)

    # Get indices of top k similarities
    {top_similarities, top_indices} =
      similarities
      |> Nx.to_flat_list()
      |> Enum.with_index()
      |> Enum.sort_by(fn {similarity, _idx} -> similarity end, :desc)
      |> Enum.take(k)
      |> Enum.unzip()

    # Return documents with their similarity scores
    top_indices
    |> Enum.zip(top_similarities)
    |> Enum.map(fn {idx, similarity} ->
      {Enum.at(store.documents, idx), similarity}
    end)
  end

  defp cosine_similarity_batch(query_embedding, embeddings_tensor) do
    # Normalize the query embedding
    query_norm = Nx.LinAlg.norm(query_embedding)
    query_normalized = Nx.divide(query_embedding, query_norm)

    # Normalize all stored embeddings
    embeddings_norms = Nx.LinAlg.norm(embeddings_tensor, axes: [1])

    embeddings_normalized =
      Nx.divide(
        embeddings_tensor,
        Nx.reshape(embeddings_norms, {Nx.axis_size(embeddings_tensor, 0), 1})
      )

    # Calculate dot product (cosine similarity for normalized vectors)
    Nx.dot(embeddings_normalized, query_normalized)
  end
end
