defmodule FamilyTreeAgent.AI.Clients.OpenAI do
  @moduledoc """
  OpenAI-based implementation of the AI client.

  Provides embedding and chat capabilities using OpenAI's API
  through the openai_ex library.
  """

  @behaviour FamilyTreeAgent.AI.Clients.RAGBehavior

  # Default model configurations
  @default_embedding_model "text-embedding-3-small"
  @default_chat_model "gpt-4o-mini"

  @type t :: %__MODULE__{
          api_key: String.t(),
          embedding_model: String.t(),
          chat_model: String.t(),
          organization_id: String.t() | nil
        }

  defstruct [
    :api_key,
    :embedding_model,
    :chat_model,
    :organization_id
  ]

  @impl true
  def init(config \\ []) do
    api_key = get_api_key(config)
    embedding_model = Keyword.get(config, :embedding_model, @default_embedding_model)
    chat_model = Keyword.get(config, :chat_model, @default_chat_model)
    organization_id = Keyword.get(config, :organization_id)

    IO.puts("🤖 Initializing OpenAI client...")
    IO.puts("   Embedding model: #{embedding_model}")
    IO.puts("   Chat model: #{chat_model}")

    client = %__MODULE__{
      api_key: api_key,
      embedding_model: embedding_model,
      chat_model: chat_model,
      organization_id: organization_id
    }

    # Test connection to OpenAI
    case test_connection(client) do
      :ok ->
        IO.puts("✅ OpenAI client initialized successfully!")
        {:ok, client}

      {:error, reason} ->
        IO.puts("❌ Failed to connect to OpenAI: #{reason}")
        {:error, reason}
    end
  end

  @impl true
  def create_embedding(%__MODULE__{} = client, text) when is_binary(text) do
    # Create OpenAI client
    openai_client = OpenaiEx.new(client.api_key)

    # Create embedding request
    embedding_request = OpenaiEx.Embeddings.new(
      model: client.embedding_model,
      input: text,
      encoding_format: "float"
    )

    case OpenaiEx.Embeddings.create(openai_client, embedding_request) do
      {:ok, %{"data" => [%{"embedding" => embedding}]}} ->
        # Convert list to Nx tensor and normalize
        embedding
        |> Nx.tensor()
        |> Nx.as_type(:f32)

      {:error, reason} ->
        raise "OpenAI embedding request failed: #{inspect(reason)}"
    end
  end

  @impl true
  def generate_text(%__MODULE__{} = client, prompt) when is_binary(prompt) do
    # Create OpenAI client
    openai_client = OpenaiEx.new(client.api_key)

    # Create chat completion request
    chat_request = OpenaiEx.Chat.Completions.new(
      model: client.chat_model,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ],
      temperature: 0.1,
      max_tokens: 500
    )

    case OpenaiEx.Chat.Completions.create(openai_client, chat_request) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        cleaned_response = String.trim(content)
        {:ok, cleaned_response}

      {:error, reason} ->
        {:error, "OpenAI generation request failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def create_embeddings_batch(%__MODULE__{} = client, texts) when is_list(texts) do
    IO.puts("Processing embeddings for #{length(texts)} texts using OpenAI...")

    # Create OpenAI client
    openai_client = OpenaiEx.new(client.api_key)

    # OpenAI supports batch embeddings, so we can send all texts at once
    embedding_request = OpenaiEx.Embeddings.new(
      model: client.embedding_model,
      input: texts,
      encoding_format: "float"
    )

    case OpenaiEx.Embeddings.create(openai_client, embedding_request) do
      {:ok, %{"data" => embeddings_data}} ->
        # Zip texts with their corresponding embeddings
        texts
        |> Enum.zip(embeddings_data)
        |> Enum.map(fn {text, %{"embedding" => embedding}} ->
          tensor_embedding =
            embedding
            |> Nx.tensor()
            |> Nx.as_type(:f32)

          {text, tensor_embedding}
        end)

      {:error, reason} ->
        # Fallback to individual requests if batch fails
        IO.puts("⚠️  Batch embedding failed, falling back to individual requests: #{inspect(reason)}")

        texts
        |> Enum.with_index()
        |> Enum.map(fn {text, idx} ->
          IO.puts("Processing text #{idx + 1}/#{length(texts)}")
          embedding = create_embedding(client, text)
          {text, embedding}
        end)
    end
  end

  @impl true
  def info(%__MODULE__{} = client) do
    %{
      embedding_model: client.embedding_model,
      chat_model: client.chat_model,
      provider: "OpenAI",
      base_url: "https://api.openai.com"
    }
  end

  # Private helper functions

  defp get_api_key(config) do
    case Keyword.get(config, :api_key) do
      nil ->
        case System.get_env("OPENAI_API_KEY") do
          nil ->
            raise """
            OpenAI API key not found. Please set it via:
            1. Environment variable: OPENAI_API_KEY
            2. Config parameter: api_key: "your-key"
            """

          api_key -> api_key
        end

      api_key -> api_key
    end
  end


  defp test_connection(%__MODULE__{} = client) do
    # Test with a simple embedding request
    test_text = "test"

    try do
      _embedding = create_embedding(client, test_text)
      :ok
    rescue
      error ->
        {:error, Exception.message(error)}
    catch
      :exit, reason -> {:error, "Process exit: #{inspect(reason)}"}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
    end
  end
end
