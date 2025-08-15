defmodule FamilyTreeAgent.AI.RAGClient do
  @moduledoc """
  Bumblebee-based implementation of the AI client.

  Provides embedding and chat capabilities using Hugging Face models
  through the Bumblebee library.
  """

  @behaviour FamilyTreeAgent.AI.RAGBehavior

  # Default model configurations
  @default_embedding_model "sentence-transformers/all-MiniLM-L6-v2"
  @default_chat_model "google/gemma-2b"

  @type t :: %__MODULE__{
          embedding_model: any(),
          embedding_tokenizer: any(),
          chat_model: any(),
          chat_tokenizer: any(),
          generation_config: any(),
          embedding_model_name: String.t(),
          chat_model_name: String.t()
        }

  defstruct [
    :embedding_model,
    :embedding_tokenizer,
    :chat_model,
    :chat_tokenizer,
    :generation_config,
    :embedding_model_name,
    :chat_model_name
  ]

  @impl true
  def init(config \\ []) do
    # Set EXLA as the default backend for better performance
    Nx.global_default_backend(EXLA.Backend)

    embedding_model_name = Keyword.get(config, :embedding_model, @default_embedding_model)
    chat_model_name = Keyword.get(config, :chat_model, @default_chat_model)

    IO.puts("🤖 Initializing AI client...")
    IO.puts("   Embedding model: #{embedding_model_name}")
    IO.puts("   Chat model: #{chat_model_name}")

    with {:ok, embedding_model} <- load_embedding_model(embedding_model_name),
         {:ok, embedding_tokenizer} <- load_embedding_tokenizer(embedding_model_name),
         {:ok, chat_model, chat_tokenizer, generation_config} <- load_chat_model(chat_model_name, config) do

      client = %__MODULE__{
        embedding_model: embedding_model,
        embedding_tokenizer: embedding_tokenizer,
        chat_model: chat_model,
        chat_tokenizer: chat_tokenizer,
        generation_config: generation_config,
        embedding_model_name: embedding_model_name,
        chat_model_name: chat_model_name
      }

      IO.puts("✅ AI client initialized successfully!")
      {:ok, client}
    else
      error -> {:error, error}
    end
  end

  @impl true
  def create_embedding(%__MODULE__{} = client, text) when is_binary(text) do
    # Tokenize the input text
    inputs = Bumblebee.apply_tokenizer(client.embedding_tokenizer, text)

    # Get embeddings from the model
    outputs = Axon.predict(client.embedding_model.model, client.embedding_model.params, inputs)

    # Handle the sentence-transformers model output format
    # The model returns: %{hidden_states: #Axon.None<...>, attentions: #Axon.None<...>, logits: #Nx.Tensor<...>}
    # We need to find actual tensors and ignore Axon.None values
    cond do
      Map.has_key?(outputs, :logits) and match?(%Nx.Tensor{}, outputs.logits) ->
        # For sentence transformers, we use the logits and do mean pooling
        outputs.logits
        # Mean pool across sequence length
        |> Nx.mean(axes: [1])
        # Remove batch dimension
        |> Nx.squeeze(axes: [0])

      Map.has_key?(outputs, :hidden_states) and match?(%Nx.Tensor{}, outputs.hidden_states) ->
        # Some models use hidden_states (plural) - but only if it's a tensor
        outputs.hidden_states
        |> Nx.mean(axes: [1])
        |> Nx.squeeze(axes: [0])

      Map.has_key?(outputs, :hidden_state) and match?(%Nx.Tensor{}, outputs.hidden_state) ->
        # Some models use hidden_state (singular) - but only if it's a tensor
        outputs.hidden_state
        |> Nx.mean(axes: [1])
        |> Nx.squeeze(axes: [0])

      true ->
        # Fallback: find the first actual tensor in outputs (ignore Axon.None values)
        actual_tensor =
          outputs
          |> Map.values()
          |> Enum.find(&match?(%Nx.Tensor{}, &1))

        case actual_tensor do
          nil ->
            IO.puts("Available outputs: #{inspect(Map.keys(outputs))}")

            outputs
            |> Map.to_list()
            |> Enum.each(fn {k, v} ->
              IO.puts("#{k}: #{inspect(v, structs: false, limit: 2)}")
            end)

            raise "No tensor found in model outputs: #{inspect(Map.keys(outputs))}"

          tensor ->
            tensor
            |> Nx.mean(axes: [1])
            |> Nx.squeeze(axes: [0])
        end
    end
  end

  @impl true
  def generate_text(%__MODULE__{} = client, prompt) when is_binary(prompt) do
    try do
      # Create text generation serving
      serving =
        Bumblebee.Text.generation(
          client.chat_model,
          client.chat_tokenizer,
          client.generation_config
        )

      # Generate response using the prompt
      result = Nx.Serving.run(serving, prompt)

      case result do
        %{results: [%{text: generated_text}]} ->
          cleaned_text = String.trim(generated_text)
          {:ok, cleaned_text}

        other ->
          {:error, "Text generation failed: #{inspect(other)}"}
      end
    rescue
      error ->
        {:error, "Text generation failed: #{inspect(error)}"}
    end
  end

  @impl true
  def create_embeddings_batch(%__MODULE__{} = client, texts) when is_list(texts) do
    IO.puts("Processing embeddings for #{length(texts)} texts...")

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
      embedding_model: client.embedding_model_name,
      chat_model: client.chat_model_name,
      provider: "Bumblebee/HuggingFace"
    }
  end

  # Private helper functions

  defp load_embedding_model(model_name) do
    IO.puts("Loading embedding model: #{model_name}")
    Bumblebee.load_model({:hf, model_name})
  end

  defp load_embedding_tokenizer(model_name) do
    IO.puts("Loading embedding tokenizer: #{model_name}")
    Bumblebee.load_tokenizer({:hf, model_name})
  end

  defp load_chat_model(model_name, config) do
    IO.puts("Loading chat model: #{model_name}")

    huggingface_token = Application.fetch_env!(:family_tree_agent, :huggingface_token)

    with {:ok, chat_model} <- Bumblebee.load_model({:hf, model_name, auth_token: huggingface_token}),
         {:ok, chat_tokenizer} <- Bumblebee.load_tokenizer({:hf, model_name, auth_token: huggingface_token}),
         {:ok, generation_config} <- Bumblebee.load_generation_config({:hf, model_name, auth_token: huggingface_token}) do

      # Configure generation parameters
      max_tokens = Keyword.get(config, :max_new_tokens, 30)
      temperature = Keyword.get(config, :temperature, 0.1)

      generation_config =
        Bumblebee.configure(generation_config,
          max_new_tokens: max_tokens,
          temperature: temperature
        )

      IO.puts("✅ Chat model loaded successfully!")
      {:ok, chat_model, chat_tokenizer, generation_config}
    end
  end
end
