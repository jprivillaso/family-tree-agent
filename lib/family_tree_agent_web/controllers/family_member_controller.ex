defmodule FamilyTreeAgentWeb.FamilyMemberController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.RAGServer

  action_fallback FamilyTreeAgentWeb.FallbackController

  @spec answer_general(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @doc """
  POST /api/family_members/answer_general
  Answers general questions about the family tree using AI.
  """
  def answer_general(conn, %{"question" => question}) do
    try do
      answer = RAGServer.answer_question(question)

      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: %{
          question: question,
          answer: answer
        }
      })
    rescue
      error ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: %{
            message: "Failed to generate answer: #{Exception.message(error)}",
            question: question
          }
        })
    end
  end
end
