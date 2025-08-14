defmodule FamilyTreeAgent.AI.InMemoryVectorStore do
  @moduledoc """
  A simple in-memory vector store using Nx for similarity calculations.
  This avoids the complexity of external dependencies while providing working RAG functionality.
  """

  @type t :: %__MODULE__{
          documents: list(String.t()),
          embeddings: Nx.Tensor.t()
        }

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

    # Use Nx.top_k for efficient top-k selection without flattening all records
    {top_similarities, top_indices} = Nx.top_k(similarities, k: k)

    # Convert tensors to lists for easier processing
    top_similarities_list = Nx.to_flat_list(top_similarities)
    top_indices_list = Nx.to_flat_list(top_indices)

    # Return documents with their similarity scores
    top_indices_list
    |> Enum.zip(top_similarities_list)
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
