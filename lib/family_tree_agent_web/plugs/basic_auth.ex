defmodule FamilyTreeAgentWeb.Plugs.BasicAuth do
  @moduledoc """
  Basic authentication plug for protecting API endpoints.

  Reads credentials from environment variables:
  - FAMILY_TREE_API_USERNAME
  - FAMILY_TREE_API_PASSWORD

  If credentials are not set, authentication is disabled (useful for development).
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_credentials() do
      {nil, nil} ->
        # No credentials configured, skip auth (development mode)
        Logger.debug("Basic auth disabled - no credentials configured")
        conn

      {username, password} ->
        authenticate(conn, username, password)
    end
  end

  defp authenticate(conn, expected_username, expected_password) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded_credentials] ->
        case decode_credentials(encoded_credentials) do
          {^expected_username, ^expected_password} ->
            Logger.debug("Basic auth successful for user: #{expected_username}")
            conn

          {provided_username, _} ->
            Logger.warning("Basic auth failed for user: #{provided_username}")
            unauthorized(conn)

          :error ->
            Logger.warning("Basic auth failed - invalid credentials format")
            unauthorized(conn)
        end

      _ ->
        Logger.debug("Basic auth required - no authorization header")
        unauthorized(conn)
    end
  end

  defp decode_credentials(encoded) do
    case Base.decode64(encoded) do
      {:ok, decoded} ->
        case String.split(decoded, ":", parts: 2) do
          [username, password] -> {username, password}
          _ -> :error
        end

      :error ->
        :error
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"Family Tree API\"")
    |> put_status(:unauthorized)
    |> json(%{
      error: "Authentication required",
      message: "Please provide valid credentials to access this endpoint"
    })
    |> halt()
  end

  defp get_credentials do
    username = System.get_env("FAMILY_TREE_API_USERNAME")
    password = System.get_env("FAMILY_TREE_API_PASSWORD")
    {username, password}
  end

  @doc """
  Helper function to check if authentication is configured.
  """
  def auth_configured? do
    case get_credentials() do
      {nil, nil} -> false
      {_, _} -> true
    end
  end
end
