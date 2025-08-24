defmodule FamilyTreeAgent.RAGServer do
  @moduledoc """
  GenServer that manages the Family Tree RAG system.

  Initializes the chat model, tokenizer, and generation config once on startup
  and keeps them in state to avoid reloading on every request.
  """

  use GenServer

  alias FamilyTreeAgent.AI.FamilyTreeRAG

  @name __MODULE__

  # Client API

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
    # Try to initialize, but don't crash if it fails
    case safe_init() do
      {:ok, rag_system} ->
        {:ok, %{status: :ready, rag_system: rag_system}}

      {:error, error} ->
        # Log the error but don't crash - start in degraded mode
        require Logger

        Logger.warning(
          "RAG system failed to initialize: #{inspect(error)}. Starting in degraded mode."
        )

        {:ok, %{status: :degraded, error: error}}
    end
  end

  defp safe_init() do
    try do
      case FamilyTreeRAG.init() do
        {:error, error} -> {:error, error}
        rag_system -> {:ok, rag_system}
      end
    rescue
      error -> {:error, Exception.message(error)}
    catch
      :exit, reason -> {:error, "Process exit: #{inspect(reason)}"}
      error -> {:error, "Unexpected error: #{inspect(error)}"}
    end
  end

  @impl GenServer
  def handle_call(
        {:answer_question, question},
        _from,
        %{status: :ready, rag_system: rag_system} = state
      ) do
    try do
      answer = FamilyTreeRAG.one_shot(rag_system, question)
      {:reply, answer, state}
    rescue
      error ->
        error_msg = "Error generating answer: #{Exception.message(error)}"
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
