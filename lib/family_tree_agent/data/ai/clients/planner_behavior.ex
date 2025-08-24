defmodule FamilyTreeAgent.AI.Clients.PlannerBehavior do
  @moduledoc """
  Behavior for AI planners that can execute tools in sequence to solve complex tasks.

  This abstraction allows for different planning strategies while maintaining
  a consistent interface for tool-based problem solving.
  """

  @doc """
  Initialize the planner with necessary configuration and available tools.
  """
  @callback init(config :: keyword()) :: {:ok, planner :: any()} | {:error, reason :: any()}

  @doc """
  Execute a plan to solve the given query using available tools.
  Returns the final result after executing all necessary tools.
  """
  @callback execute_plan(planner :: any(), query :: String.t()) ::
              {:ok, result :: any()} | {:error, reason :: any()}

  @doc """
  Get information about the planner's configuration and available tools.
  """
  @callback info(planner :: any()) :: %{
              tools: list(String.t()),
              provider: String.t(),
              description: String.t()
            }
end
