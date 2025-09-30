defmodule FamilyTreeAgent.AI.ClientFactory do
  @moduledoc """
  Factory for creating AI clients based on configuration.

  This module provides a unified interface for creating different AI clients
  (OpenAI, Ollama, etc.) based on environment configuration.
  """

  alias FamilyTreeAgent.AI.Clients.OpenAI
  alias FamilyTreeAgent.AI.Clients.Ollama

  @type client_type :: :openai | :ollama
  @type client_config :: keyword()

  @doc """
  Create an AI client based on the configured provider.

  ## Examples

      # Use default configured client
      {:ok, client} = ClientFactory.create_client()

      # Override client type
      {:ok, client} = ClientFactory.create_client(:openai)

      # Override with custom config
      {:ok, client} = ClientFactory.create_client(:openai, api_key: "custom-key")
  """
  @spec create_client() :: {:ok, any()} | {:error, any()}
  def create_client do
    client_type = get_configured_client_type()
    config = get_client_config(client_type)
    create_client(client_type, config)
  end

  @spec create_client(client_type()) :: {:ok, any()} | {:error, any()}
  def create_client(client_type) do
    config = get_client_config(client_type)
    create_client(client_type, config)
  end

  @spec create_client(client_type(), client_config()) :: {:ok, any()} | {:error, any()}
  def create_client(:openai, config) do
    OpenAI.init(config)
  end

  def create_client(:ollama, config) do
    Ollama.init(config)
  end

  def create_client(unknown_type, _config) do
    {:error, "Unknown AI client type: #{unknown_type}. Supported types: :openai, :ollama"}
  end

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
