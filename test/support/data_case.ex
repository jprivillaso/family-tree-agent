defmodule FamilyTreeAgent.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  Since we're using Neo4j instead of a traditional SQL database,
  this module provides basic test setup without database sandboxing.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import common testing utilities
      import FamilyTreeAgent.DataCase
    end
  end

  setup _tags do
    # No database setup needed for Neo4j-based tests
    :ok
  end
end
