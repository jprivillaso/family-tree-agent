defmodule FamilyTreeAgent.AI.Clients.OllamaClient do
  @moduledoc """
  Ollama-based implementation of the AI client.

  Provides embedding and chat capabilities using Ollama models
  through HTTP API calls.
  """

  @behaviour FamilyTreeAgent.AI.RAGBehavior

  # Default model configurations
  @default_embedding_model "nomic-embed-text"
  @default_chat_model "llama3.2"
  @default_base_url "http://localhost:11434"

  @type t :: %__MODULE__{
          base_url: String.t(),
          embedding_model: String.t(),
          chat_model: String.t(),
          req_client: Req.Request.t()
        }

  defstruct [
    :base_url,
    :embedding_model,
    :chat_model,
    :req_client
  ]

  @impl true
  def init(config \\ []) do
    base_url = Keyword.get(config, :base_url, @default_base_url)
    embedding_model = Keyword.get(config, :embedding_model, @default_embedding_model)
    chat_model = Keyword.get(config, :chat_model, @default_chat_model)

    IO.puts("🦙 Initializing Ollama client...")
    IO.puts("   Base URL: #{base_url}")
    IO.puts("   Embedding model: #{embedding_model}")
    IO.puts("   Chat model: #{chat_model}")

    # Create a configured Req client
    req_client =
      Req.new(
        base_url: base_url,
        headers: [{"Content-Type", "application/json"}],
        # 60 seconds timeout for model responses
        receive_timeout: 60_000
      )

    client = %__MODULE__{
      base_url: base_url,
      embedding_model: embedding_model,
      chat_model: chat_model,
      req_client: req_client
    }

    # Test connection to Ollama
    case test_connection(client) do
      :ok ->
        IO.puts("✅ Ollama client initialized successfully!")
        {:ok, client}

      {:error, reason} ->
        IO.puts("❌ Failed to connect to Ollama: #{reason}")
        {:error, reason}
    end
  end

  @impl true
  def create_embedding(%__MODULE__{} = client, text) when is_binary(text) do
    payload = %{
      model: client.embedding_model,
      prompt: text
    }

    case Req.post(client.req_client, url: "/api/embeddings", json: payload) do
      {:ok, %{status: 200, body: %{"embedding" => embedding}}} ->
        # Convert list to Nx tensor
        embedding
        |> Nx.tensor()
        |> Nx.as_type(:f32)

      {:ok, %{status: status, body: body}} ->
        raise "Ollama embedding request failed with status #{status}: #{inspect(body)}"

      {:error, reason} ->
        raise "Ollama embedding request failed: #{inspect(reason)}"
    end
  end

  @impl true
  def generate_text(%__MODULE__{} = client, prompt) when is_binary(prompt) do
    payload = %{
      model: client.chat_model,
      prompt: prompt,
      stream: false,
      options: %{
        temperature: 0.1,
        # Limit response length
        num_predict: 100
      }
    }

    case Req.post(client.req_client, url: "/api/generate", json: payload) do
      {:ok, %{status: 200, body: %{"response" => response}}} ->
        cleaned_response = String.trim(response)
        {:ok, cleaned_response}

      {:ok, %{status: status, body: body}} ->
        {:error, "Ollama generation request failed with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Ollama generation request failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def create_embeddings_batch(%__MODULE__{} = client, texts) when is_list(texts) do
    IO.puts("Processing embeddings for #{length(texts)} texts using Ollama...")

    texts
    |> Enum.with_index()
    |> Enum.map(fn {text, idx} ->
      IO.puts("Processing text #{idx + 1}/#{length(texts)}")
      embedding = create_embedding(client, text)
      {text, embedding}
    end)
  end

  @impl true
  def info(%__MODULE__{} = client) do
    %{
      embedding_model: client.embedding_model,
      chat_model: client.chat_model,
      provider: "Ollama",
      base_url: client.base_url
    }
  end

  # Private helper functions

  defp test_connection(%__MODULE__{} = client) do
    case Req.get(client.req_client, url: "/api/tags") do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        {:error, "Ollama server responded with status #{status}"}

      {:error, %{reason: :econnrefused}} ->
        {:error, "Connection refused - is Ollama running on #{client.base_url}?"}

      {:error, reason} ->
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Pull a model from Ollama if it's not already available.
  This is useful for ensuring required models are downloaded.
  """
  def pull_model(%__MODULE__{} = client, model_name) do
    IO.puts("🔄 Pulling model #{model_name} from Ollama...")

    payload = %{name: model_name}

    case Req.post(client.req_client, url: "/api/pull", json: payload) do
      {:ok, %{status: 200}} ->
        IO.puts("✅ Model #{model_name} pulled successfully!")
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to pull model with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to pull model: #{inspect(reason)}"}
    end
  end

  @doc """
  List all available models in Ollama.
  """
  def list_models(%__MODULE__{} = client) do
    case Req.get(client.req_client, url: "/api/tags") do
      {:ok, %{status: 200, body: %{"models" => models}}} ->
        model_names = Enum.map(models, & &1["name"])
        {:ok, model_names}

      {:ok, %{status: status, body: body}} ->
        {:error, "Failed to list models with status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to list models: #{inspect(reason)}"}
    end
  end
end
