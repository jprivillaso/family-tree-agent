defmodule FamilyTreeAgentWeb.FamilyMemberController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.AI.RAGServer
  alias FamilyTreeAgent.Data.FamilyTree
  alias FamilyTreeAgent.Schema.FamilyMember

  action_fallback FamilyTreeAgentWeb.FallbackController

  @doc """
  GET /api/family_members
  Lists all family members.
  """
  def index(conn, _params) do
    members = FamilyTree.list_members()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: %{
        members: Enum.map(members, &format_member/1),
        total_count: length(members)
      }
    })
  end

  @doc """
  GET /api/family_members/:id
  Gets a specific family member by ID.
  """
  def show(conn, %{"id" => id}) do
    case FamilyTree.get_member(id) do
      %FamilyMember{} = member ->
        conn
        |> put_status(:ok)
        |> json(%{
          success: true,
          data: %{
            member: format_member(member)
          }
        })

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: %{
            message: "Family member not found",
            details: "No member found with ID: #{id}"
          }
        })
    end
  end

  @doc """
  POST /api/family_members
  Creates a new family member.
  """
  def create(conn, %{"member" => member_params}) do
    case FamilyTree.create_member(member_params) do
      {:ok, %FamilyMember{} = member} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          data: %{
            member: format_member(member)
          },
          message: "Family member created successfully"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          success: false,
          error: %{
            message: "Validation failed",
            details: format_changeset_errors(changeset)
          }
        })
    end
  end

  @doc """
  PUT /api/family_members/:id
  Updates an existing family member.
  """
  def update(conn, %{"id" => id, "member" => member_params}) do
    case FamilyTree.get_member(id) do
      %FamilyMember{} = member ->
        case FamilyTree.update_member(member, member_params) do
          {:ok, %FamilyMember{} = updated_member} ->
            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              data: %{
                member: format_member(updated_member)
              },
              message: "Family member updated successfully"
            })

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{
              success: false,
              error: %{
                message: "Validation failed",
                details: format_changeset_errors(changeset)
              }
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: %{
            message: "Family member not found",
            details: "No member found with ID: #{id}"
          }
        })
    end
  end

  @doc """
  DELETE /api/family_members/:id
  Deletes a family member.
  """
  def delete(conn, %{"id" => id}) do
    case FamilyTree.get_member(id) do
      %FamilyMember{} = member ->
        case FamilyTree.delete_member(member) do
          {:ok, _member} ->
            conn
            |> put_status(:ok)
            |> json(%{
              success: true,
              message: "Family member deleted successfully"
            })

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{
              success: false,
              error: %{
                message: "Failed to delete family member",
                details: format_changeset_errors(changeset)
              }
            })
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          success: false,
          error: %{
            message: "Family member not found",
            details: "No member found with ID: #{id}"
          }
        })
    end
  end

  @spec answer(Plug.Conn.t(), map()) :: Plug.Conn.t()
  @doc """
  POST /api/family_members/answer
  Answers questions about a specific family member using AI.
  """
  def answer(conn, %{"person_name" => person_name, "question" => question}) do
    full_question = "Tell me about #{person_name}: #{question}"

    try do
      answer = RAGServer.answer_question(full_question)

      conn
      |> put_status(:ok)
      |> json(%{
        success: true,
        data: %{
          person_name: person_name,
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
            person_name: person_name,
            question: question
          }
        })
    end
  end

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

  # Private helper functions
  defp format_member(member) do
    %{
      id: member.id,
      name: member.name,
      birth_date: format_date(member.birth_date),
      death_date: format_date(member.death_date),
      bio: member.bio,
      relationships: member.relationships,
      metadata: member.metadata,
      inserted_at: member.inserted_at,
      updated_at: member.updated_at
    }
  end

  defp format_date(nil), do: nil
  defp format_date(date), do: Date.to_iso8601(date)

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
