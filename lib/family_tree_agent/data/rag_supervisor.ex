defmodule FamilyTreeAgent.RAGSupervisor do
  @moduledoc """
  Supervisor for AI/RAG related processes.

  Uses a :rest_for_one strategy and allows the RAG server to fail
  without bringing down the entire application.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {FamilyTreeAgent.RAGServer, []}
    ]

    # Use :temporary restart strategy so if RAG server fails to start,
    # it won't be restarted and won't crash the supervisor
    opts = [strategy: :one_for_one, max_restarts: 3, max_seconds: 60]

    Supervisor.init(children, opts)
  end
end
