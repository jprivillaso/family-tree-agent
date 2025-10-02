defmodule FamilyTreeAgent.AI.Clients.Client do
  @moduledoc """
  Unified client interface for AI operations.

  This module provides both factory functions for creating AI clients
  and a clean interface for AI operations using proper pattern matching
  and behavior calls.
  """

  alias FamilyTreeAgent.AI.Clients.OpenAI
  alias FamilyTreeAgent.AI.Clients.Ollama

  @type client_type :: :openai | :ollama
  @type client_config :: keyword()
  @type client :: OpenAI.t() | Ollama.t()

  # Factory functions

  @doc """
  Create an AI client based on the configured provider.

  ## Examples

      # Use default configured client
      {:ok, client} = Client.create()

      # Override client type
      {:ok, client} = Client.create(:openai)

      # Override with custom config
      {:ok, client} = Client.create(:openai, api_key: "custom-key")
  """
  @spec create() :: {:ok, client()} | {:error, any()}
  def create do
    client_type = get_configured_client_type()
    config = get_client_config(client_type)
    create(client_type, config)
  end

  @spec create(client_type()) :: {:ok, client()} | {:error, any()}
  def create(client_type) do
    config = get_client_config(client_type)
    create(client_type, config)
  end

  @spec create(client_type(), client_config()) :: {:ok, client()} | {:error, any()}
  def create(:openai, config) do
    OpenAI.init(config)
  end

  def create(:ollama, config) do
    Ollama.init(config)
  end

  def create(unknown_type, _config) do
    {:error, "Unknown AI client type: #{unknown_type}. Supported types: :openai, :ollama"}
  end

  # Client operations using pattern matching

  @doc """
  Create an embedding for the given text using the provided client.
  """
  @spec create_embedding(client(), String.t()) :: Nx.Tensor.t()
  def create_embedding(%OpenAI{} = client, text) when is_binary(text) do
    OpenAI.create_embedding(client, text)
  end

  def create_embedding(%Ollama{} = client, text) when is_binary(text) do
    Ollama.create_embedding(client, text)
  end

  @doc """
  Generate text using the chat model with the given prompt.
  """
  @spec generate_text(client(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def generate_text(%OpenAI{} = client, prompt) when is_binary(prompt) do
    OpenAI.generate_text(client, prompt)
  end

  def generate_text(%Ollama{} = client, prompt) when is_binary(prompt) do
    Ollama.generate_text(client, prompt)
  end

  @doc """
  Create embeddings for multiple texts in batch.
  """
  @spec create_embeddings_batch(client(), [String.t()]) :: [{String.t(), Nx.Tensor.t()}]
  def create_embeddings_batch(%OpenAI{} = client, texts) when is_list(texts) do
    OpenAI.create_embeddings_batch(client, texts)
  end

  def create_embeddings_batch(%Ollama{} = client, texts) when is_list(texts) do
    Ollama.create_embeddings_batch(client, texts)
  end

  @doc """
  Get information about the client's models and configuration.
  """
  @spec info(client()) :: %{
          embedding_model: String.t(),
          chat_model: String.t(),
          provider: String.t(),
          base_url: String.t()
        }
  def info(%OpenAI{} = client) do
    OpenAI.info(client)
  end

  def info(%Ollama{} = client) do
    Ollama.info(client)
  end

  @doc """
  Get the provider name for the given client.
  """
  @spec provider(client()) :: String.t()
  def provider(%OpenAI{}), do: "OpenAI"
  def provider(%Ollama{}), do: "Ollama"

  @doc """
  Check if the client is of a specific type.
  """
  @spec client_type?(client(), client_type()) :: boolean()
  def client_type?(%OpenAI{}, :openai), do: true
  def client_type?(%Ollama{}, :ollama), do: true
  def client_type?(_, _), do: false

  # Configuration functions

  @doc """
  Get the currently configured client type.
  """
  @spec get_configured_client_type() :: client_type()
  def get_configured_client_type do
    Application.get_env(:family_tree_agent, :ai_client_type, :openai)
  end

  @doc """
  Get configuration for a specific client type.
  """
  @spec get_client_config(client_type()) :: client_config()
  def get_client_config(client_type) do
    base_config = Application.get_env(:family_tree_agent, :ai_clients, [])
    Keyword.get(base_config, client_type, [])
  end

  @doc """
  List all available client types.
  """
  @spec available_client_types() :: [client_type()]
  def available_client_types do
    [:openai, :ollama]
  end

  @doc """
  Get information about the current client configuration.
  """
  @spec client_info() :: %{
          current_type: client_type(),
          available_types: [client_type()],
          config: client_config()
        }
  def client_info do
    current_type = get_configured_client_type()

    %{
      current_type: current_type,
      available_types: available_client_types(),
      config: get_client_config(current_type)
    }
  end
end
