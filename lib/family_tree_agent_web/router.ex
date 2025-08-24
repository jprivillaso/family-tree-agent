defmodule FamilyTreeAgentWeb.Router do
  use FamilyTreeAgentWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FamilyTreeAgentWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  scope "/api", FamilyTreeAgentWeb do
    pipe_through :api

    # Health check endpoint
    get "/health", HealthController, :health

    resources "/family_members", FamilyMemberController, except: [:new, :edit]

    # AI-powered answer endpoints
    post "/family_members/answer_general", FamilyMemberController, :answer_general

    # OPTIONS routes for CORS support
    options "/family_members", FamilyMemberController, :options
    options "/family_members/:id", FamilyMemberController, :options
    options "/family_members/answer", FamilyMemberController, :options
    options "/family_members/answer_general", FamilyMemberController, :options
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:family_tree_agent, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FamilyTreeAgentWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
