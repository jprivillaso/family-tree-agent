defmodule FamilyTreeAgentWeb.FamilyTreeController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.Data.FamilyTree

  action_fallback FamilyTreeAgentWeb.FallbackController

  @doc """
  GET /api/family_tree
  Gets the complete family tree structure with relationships.
  """
  def show(conn, _params) do
    tree = FamilyTree.get_family_tree()

    conn
    |> put_status(:ok)
    |> json(%{
      success: true,
      data: %{
        family_tree: tree
      }
    })
  end
end
