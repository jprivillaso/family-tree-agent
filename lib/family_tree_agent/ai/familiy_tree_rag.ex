defmodule FamilyTreeAgent.AI.FamilyTreeRAG do
  @moduledoc """
  This module demonstrates RAG (Retrieval-Augmented Generation) using Elixir, Bumblebee, and Nx.
  This version includes both retrieval and natural language generation capabilities.
  """

  alias FamilyTreeAgent.AI.FileProcessor
  alias FamilyTreeAgent.AI.InMemoryVectorStore

  # Configuration
  @embedding_model_repo "sentence-transformers/all-MiniLM-L6-v2"
  @chat_model_repo "google/gemma-2b"

  @type t :: %__MODULE__{
          embedding_model: any(),
          embedding_tokenizer: any(),
          chat_model: any(),
          chat_tokenizer: any(),
          generation_config: any(),
          vector_store: InMemoryVectorStore.t()
        }

  defstruct [
    :embedding_model,
    :embedding_tokenizer,
    :chat_model,
    :chat_tokenizer,
    :generation_config,
    :vector_store
  ]

  defp huggingface_token do
    Application.fetch_env!(:family_tree_agent, :huggingface_token)
  end

  @doc """
  Main function to run the RAG system interactively.
  """
  def run! do
    case init() do
      %__MODULE__{} = rag_system ->
        IO.puts("\n✅ RAG System initialized successfully!")
        IO.puts("💡 Try questions like:")
        IO.puts("   - 'Tell me about Jane Doe'")
        IO.puts("   - 'What are Alice's hobbies?'")
        IO.puts("   - 'Who is married to John Doe?'")

        interactive_loop(rag_system)

      {:error, error} ->
        IO.puts("Error initializing RAG system: #{inspect(error)}")
        raise error
    end
  end

  def init do
    # Set EXLA as the default backend for better performance
    Nx.global_default_backend(EXLA.Backend)

    with {:ok, embedding_model} <- Bumblebee.load_model({:hf, @embedding_model_repo}),
         {:ok, embedding_tokenizer} <- Bumblebee.load_tokenizer({:hf, @embedding_model_repo}),
         {:ok, chat_model, chat_tokenizer, generation_config} <- load_chat_model() do
      IO.puts("Loading and processing documents...")
      documents = FileProcessor.load_documents!()
      chunks = FileProcessor.split_documents(documents)

      IO.puts("Creating embeddings for #{length(chunks)} chunks...")

      documents_with_embeddings =
        create_embeddings_for_chunks(chunks, embedding_model, embedding_tokenizer)

      IO.puts("Building vector store...")
      vector_store = InMemoryVectorStore.new(documents_with_embeddings)

      %__MODULE__{
        embedding_model: embedding_model,
        embedding_tokenizer: embedding_tokenizer,
        chat_model: chat_model,
        chat_tokenizer: chat_tokenizer,
        generation_config: generation_config,
        vector_store: vector_store
      }
    end
  end

  @spec interactive_loop(t()) :: :ok
  def interactive_loop(rag_system) do
    query = IO.gets("\nEnter your query (or 'exit' to exit):")

    case query do
      "exit" ->
        IO.puts("👋 Goodbye!")

      "" ->
        IO.puts("Please enter a valid query.")
        interactive_loop(rag_system)

      _ ->
        IO.puts("\n🔍 Retrieving relevant documents...")
        relevant_docs_with_scores = similarity_search(rag_system, query, 3)

        relevant_docs_with_scores =
          Enum.reject(relevant_docs_with_scores, fn {_doc, score} -> score < 0.05 end)

        IO.puts("\n📄 Top most relevant documents:")

        relevant_docs_with_scores
        |> Enum.with_index(1)
        |> Enum.each(fn {{chunk, score}, index} ->
          preview = String.slice(chunk, 0, 100) <> "..."
          IO.puts("#{index}. (Score: #{Float.round(score, 3)}) #{preview}")
          IO.puts(String.duplicate("-", 50))
        end)

        response = generate_ai_response(rag_system, query, relevant_docs_with_scores)
        IO.puts("\n💬 Response:\n#{response}")

        interactive_loop(rag_system)
    end
  end

  @spec one_shot(t(), String.t()) :: String.t() | {:error, String.t()}
  def one_shot(rag_system, query) do
    relevant_docs_with_scores = similarity_search(rag_system, query, 3)

    relevant_docs_with_scores =
      Enum.reject(relevant_docs_with_scores, fn {_doc, score} -> score < 0.05 end)

    generate_ai_response(rag_system, query, relevant_docs_with_scores)
  end

  defp load_chat_model do
    IO.puts("Attempting to load chat model...")

    huggingface_token = huggingface_token()

    {:ok, chat_model} =
      Bumblebee.load_model({:hf, @chat_model_repo, auth_token: huggingface_token})

    {:ok, chat_tokenizer} =
      Bumblebee.load_tokenizer({:hf, @chat_model_repo, auth_token: huggingface_token})

    {:ok, generation_config} =
      Bumblebee.load_generation_config({:hf, @chat_model_repo, auth_token: huggingface_token})

    # Configure generation parameters - focused responses
    generation_config =
      Bumblebee.configure(generation_config,
        # Very short to force concise answers
        max_new_tokens: 30,
        # Low temperature for more focused, deterministic responses
        temperature: 0.1
      )

    IO.puts("✅ Chat model loaded successfully!")
    {:ok, chat_model, chat_tokenizer, generation_config}
  end

  defp generate_ai_response(rag_system, query, relevant_docs_with_scores) do
    # Extract the retrieved documents as context
    relevant_docs = Enum.map(relevant_docs_with_scores, fn {doc, _score} -> doc end)
    context = Enum.join(relevant_docs, "\n\n")

    # Create a prompt that includes the RAG context (single answer format)
    prompt = """
    Answer in one sentence. Avoid explanations about your answer.

    The most two common questions are:

    1. Who is the person?
    You should return the name of the person and a summary of the person's bio and relationships.

    Example:
    "Bill Gates is a software engineer at Microsoft. He is married to Melinda Gates and has three children."
    "Elon Musk is a software engineer at Tesla. He is married to Grimes and has six children."

    2. What is the person's relationship to the person?
    You should return the name of the person and a summary of the person's relationship to the person.

    Example:
    "Bill Gates is the father of Melinda Gates."
    "Elon Musk is the father of Grimes."

    3. General Case
    You should return a single line with the person's name. Try to match the question to an attribute of the person
    - name
    - biography
    - relationships
    - hobbies

    Once you identify the most relevant attribute, return a summary of that attribute and the person's name.

    Example:
    Q: What is John Doe's hobbies?
    A: John Doe likes to play tennis and read books.

    Q: What is John Doe's relationship to Jane Doe?
    A: John Doe is the father of Jane Doe.

    Q: What is Alice Doe's hobbies?
    A: Alice Doe likes to read and swim.

    Omit using Answer, Question and explanation in your response.

    Context:
    #{context}

    Question:
    #{query}
    """

    try do
      # Create text generation serving
      serving =
        Bumblebee.Text.generation(
          rag_system.chat_model,
          rag_system.chat_tokenizer,
          rag_system.generation_config
        )

      # Generate response using the RAG context
      IO.puts("🤖 Generating AI response using RAG context...")
      result = Nx.Serving.run(serving, prompt)

      case result do
        %{results: [%{text: generated_text}]} ->
          cleaned_text = String.trim(generated_text)
          "🤖 AI Response: #{cleaned_text}."

        other ->
          {:error, "Text generation failed: #{inspect(other)}"}
      end
    rescue
      error ->
        {:error, "Text generation failed: #{inspect(error)}"}
    end
  end

  defp similarity_search(rag_system, query, k) do
    query_embedding =
      create_embedding(query, rag_system.embedding_model, rag_system.embedding_tokenizer)

    InMemoryVectorStore.similarity_search(rag_system.vector_store, query_embedding, k)
  end

  defp create_embeddings_for_chunks(chunks, model, tokenizer) do
    IO.puts("Processing embeddings for #{length(chunks)} chunks...")

    chunks
    |> Enum.with_index()
    |> Enum.map(fn {chunk, idx} ->
      IO.puts("Processing chunk #{idx + 1}/#{length(chunks)}")

      embedding = create_embedding(chunk, model, tokenizer)
      {chunk, embedding}
    end)
  end

  defp create_embedding(text, model, tokenizer) do
    # Tokenize the input text
    inputs = Bumblebee.apply_tokenizer(tokenizer, text)

    # Get embeddings from the model
    outputs = Axon.predict(model.model, model.params, inputs)

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
end
