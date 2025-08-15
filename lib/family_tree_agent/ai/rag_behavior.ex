defmodule FamilyTreeAgent.AI.RAGBehavior do
  @moduledoc """
  Behavior for AI clients that provide embedding and chat capabilities.

  This abstraction allows for easy switching between different AI providers
  while maintaining a consistent interface.
  """

  @doc """
  Initialize the AI client with necessary models and configurations.
  """
  @callback init(config :: keyword()) :: {:ok, client :: any()} | {:error, reason :: any()}

  @doc """
  Create an embedding for the given text.
  Returns a normalized embedding vector as an Nx tensor.
  """
  @callback create_embedding(client :: any(), text :: String.t()) :: Nx.Tensor.t()

  @doc """
  Generate text using the chat model with the given prompt.
  Returns the generated text as a string.
  """
  @callback generate_text(client :: any(), prompt :: String.t()) ::
    {:ok, String.t()} | {:error, reason :: any()}

  @doc """
  Create embeddings for multiple texts in batch for better performance.
  Returns a list of {text, embedding} tuples.
  """
  @callback create_embeddings_batch(client :: any(), texts :: list(String.t())) ::
    list({String.t(), Nx.Tensor.t()})

  @doc """
  Get information about the client's models and configuration.
  """
  @callback info(client :: any()) :: %{
    embedding_model: String.t(),
    chat_model: String.t(),
    provider: String.t()
  }
end
