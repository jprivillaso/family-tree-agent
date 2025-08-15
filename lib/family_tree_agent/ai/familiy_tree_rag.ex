defmodule FamilyTreeAgent.AI.FamilyTreeRAG do
  @moduledoc """
  This module demonstrates RAG (Retrieval-Augmented Generation) using Elixir and AI clients.
  This version includes both retrieval and natural language generation capabilities
  with a pluggable AI client abstraction.
  """

  alias FamilyTreeAgent.AI.FileProcessor
  alias FamilyTreeAgent.AI.InMemoryVectorStore
  alias FamilyTreeAgent.AI.Clients.OllamaClient

  @type t :: %__MODULE__{
          ai_client: any(),
          vector_store: InMemoryVectorStore.t()
        }

  defstruct [
    :ai_client,
    :vector_store
  ]

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

  def init(client_config \\ []) do
    with {:ok, ai_client} <- OllamaClient.init(client_config) do
      IO.puts("Loading and processing documents...")
      documents = FileProcessor.load_documents!()

      IO.puts("Creating embeddings for #{length(documents)} chunks...")
      documents_with_embeddings = OllamaClient.create_embeddings_batch(ai_client, documents)

      IO.puts("Building vector store...")
      vector_store = InMemoryVectorStore.new(documents_with_embeddings)

      %__MODULE__{
        ai_client: ai_client,
        vector_store: vector_store
      }
    else
      {:error, error} -> {:error, error}
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

        case generate_ai_response(rag_system, query, relevant_docs_with_scores) do
          {:ok, response} -> IO.puts("\n💬 Response:\n#{response}")
          {:error, error} -> IO.puts("\n❌ Error generating response: #{error}")
        end

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

    IO.puts("🤖 Generating AI response using RAG context...")

    case OllamaClient.generate_text(rag_system.ai_client, prompt) do
      {:ok, generated_text} ->
        "🤖 AI Response: #{generated_text}."

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp similarity_search(rag_system, query, k) do
    query_embedding = OllamaClient.create_embedding(rag_system.ai_client, query)
    InMemoryVectorStore.similarity_search(rag_system.vector_store, query_embedding, k)
  end
end
