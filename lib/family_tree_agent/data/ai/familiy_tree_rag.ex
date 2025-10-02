defmodule FamilyTreeAgent.AI.FamilyTreeRAG do
  @moduledoc """
  This module demonstrates RAG (Retrieval-Augmented Generation) using Elixir and AI clients.
  This version includes both retrieval and natural language generation capabilities
  with a pluggable AI client abstraction.
  """

  alias FamilyTreeAgent.AI.FileProcessor
  alias FamilyTreeAgent.AI.InMemoryVectorStore
  alias FamilyTreeAgent.AI.Clients.Client, as: AIClient

  @type t :: %__MODULE__{
          ai_client: any(),
          vector_store: InMemoryVectorStore.t()
        }

  defstruct [
    :ai_client,
    :vector_store
  ]

  def init(_client_config) do
    with {:ok, ai_client} <- AIClient.create() do
      IO.puts("Loading and processing documents...")
      documents = FileProcessor.load_documents!()

      IO.puts("Creating embeddings for #{length(documents)} chunks...")
      documents_with_embeddings = AIClient.create_embeddings_batch(ai_client, documents)

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
    You are a Family Tree assistant that ONLY answers questions about family members and relationships.

    CRITICAL RULE: If the question is NOT about family members, relationships, or personal information about people in the family tree, you MUST respond with exactly: "I can only answer questions about the Family Tree"

    Examples of questions you should NOT answer:
    - Programming or coding questions
    - Technical help requests
    - General knowledge questions
    - Math calculations
    - Weather, news, or current events
    - Anything unrelated to family relationships

    Examples of questions you SHOULD answer:
    - "Who is John Doe?"
    - "What is Mary's relationship to Peter?"
    - "How many children does Sarah have?"
    - "When was Michael born?"
    - "What is Jane's occupation?"

    If the question IS about family members, answer in one sentence. Avoid explanations about your answer.

    The most common question types are:

    1. Who is the person?
    You should return the name of the person and a summary of the person's bio and relationships.

    Example:
    "Bill Gates is a software engineer at Microsoft. He is married to Melinda Gates and has three children."

    2. What is the person's relationship to another person?
    You should return the relationship between the two people.

    Example:
    "Bill Gates is the father of Jennifer Gates."

    3. General personal information
    Try to match the question to an attribute of the person: name, bio, relationships, occupation, location, etc.

    Example:
    Q: What is John Doe's occupation?
    A: John Doe is a software engineer.

    Omit using "Answer:", "Question:" and explanations in your response.

    Context:
    #{context}

    Question:
    #{query}
    """

    IO.puts("🤖 Generating AI response using RAG context...")

    case AIClient.generate_text(rag_system.ai_client, prompt) do
      {:ok, generated_text} ->
        "🤖 AI Response: #{generated_text}."

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp similarity_search(rag_system, query, k) do
    query_embedding = AIClient.create_embedding(rag_system.ai_client, query)
    InMemoryVectorStore.similarity_search(rag_system.vector_store, query_embedding, k)
  end
end
