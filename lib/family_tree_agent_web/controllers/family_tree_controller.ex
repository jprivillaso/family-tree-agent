defmodule FamilyTreeAgentWeb.FamilyTreeController do
  use FamilyTreeAgentWeb, :controller

  alias FamilyTreeAgent.FamilyTree

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

  @doc """
  OPTIONS /api/family_tree
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
end
