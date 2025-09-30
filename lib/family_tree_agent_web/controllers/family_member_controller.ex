defmodule FamilyTreeAgentWeb.FamilyMemberController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.RAGServer
  alias FamilyTreeAgent.Data.FamilyTree

  require Logger

  action_fallback FamilyTreeAgentWeb.FallbackController

  @spec answer(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def answer(conn, %{"question" => question}) do
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
            message: "Failed to generate answer: #{inspect(error)}",
            question: question
          }
        })
    end
  end

  @spec family_members(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def family_members(conn, _params) do
    case FamilyTree.get_all_members() do
      {:ok, family_members} ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: %{
            family_members: family_members,
            total_members: length(family_members)
          }
        })

      {:error, reason} ->
        Logger.error("Failed to fetch family members: #{inspect(reason)}")

        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: %{
            message: "Failed to fetch family members: #{inspect(reason)}"
          }
        })
    end
  end
end
