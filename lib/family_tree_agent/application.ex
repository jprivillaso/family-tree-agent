defmodule FamilyTreeAgent.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FamilyTreeAgentWeb.Telemetry,
      FamilyTreeAgent.Repo,
      {DNSCluster, query: Application.get_env(:family_tree_agent, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FamilyTreeAgent.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FamilyTreeAgent.Finch},
      # Start a worker by calling: FamilyTreeAgent.Worker.start_link(arg)
      # {FamilyTreeAgent.Worker, arg},
      # Start to serve requests, typically the last entry
      FamilyTreeAgentWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FamilyTreeAgent.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FamilyTreeAgentWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
