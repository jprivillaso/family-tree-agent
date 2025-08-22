defmodule FamilyTreeAgent.AI.RAGServer do
  @moduledoc """
  GenServer that manages the Family Tree RAG system.

  Initializes the chat model, tokenizer, and generation config once on startup
  and keeps them in state to avoid reloading on every request.
  """

  use GenServer

  alias FamilyTreeAgent.AI.FamiliyTreeGraphRAG

  @name __MODULE__

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @spec answer_question(String.t()) :: String.t()
  def answer_question(question) do
    GenServer.call(@name, {:answer_question, question}, 30_000)
  end

  @spec get_state() :: map()
  def get_state do
    GenServer.call(@name, :get_state)
  end

  @spec ready?() :: boolean()
  def ready? do
    case get_state() do
      %{status: :ready} -> true
      _ -> false
    end
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    Logger.info("Initializing RAG Server with Graph RAG system...")

    case FamiliyTreeGraphRAG.init() do
      %FamiliyTreeGraphRAG{} = rag_system ->
        Logger.info("✅ Graph RAG system initialized successfully")
        {:ok, %{status: :ready, rag_system: rag_system}}

      {:error, error} ->
        Logger.error("❌ Failed to initialize Graph RAG system: #{inspect(error)}")
        {:ok, %{status: :degraded, error: inspect(error)}}
    end
  end

  @impl GenServer
  def handle_call(
        {:answer_question, question},
        _from,
        %{status: :ready, rag_system: rag_system} = state
      ) do
    try do
      case FamiliyTreeGraphRAG.answer(rag_system, question) do
        {:ok, answer} -> {:reply, answer, state}
        {:error, error} -> {:reply, "Error: #{error}", state}
      end
    rescue
      error ->
        error_msg = "Error generating answer: #{Exception.message(error)}"
        Logger.error(error_msg)
        {:reply, error_msg, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:answer_question, _question},
        _from,
        %{status: :degraded, error: error} = state
      ) do
    error_msg = "RAG system is not available: #{error}"
    {:reply, error_msg, state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
