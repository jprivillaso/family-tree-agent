defmodule FamilyTreeAgent.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  def migrate do
    # No database migrations needed - using Neo4j for data storage
    :ok
  end

  def rollback(_repo, _version) do
    # No database rollbacks needed - using Neo4j for data storage
    :ok
  end
end
