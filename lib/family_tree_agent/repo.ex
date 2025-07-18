defmodule FamilyTreeAgent.Repo do
  use Ecto.Repo,
    otp_app: :family_tree_agent,
    adapter: Ecto.Adapters.Postgres
end
