defmodule FamilyTreeAgentWeb.FamilyMemberController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.FamilyTree
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

  @doc """
  OPTIONS /api/family_members/*
  Handles preflight CORS requests.
  """
  def options(conn, _params) do
    conn
    |> put_status(:ok)
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type, authorization")
    |> send_resp(200, "")
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
