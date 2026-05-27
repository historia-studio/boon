defmodule BoonWeb.Router do
  use BoonWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BoonWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_user do
    plug :ensure_authenticated_user
  end

  scope "/", BoonWeb do
    pipe_through :browser

    sign_in_route auth_routes_prefix: "/auth", on_mount: [{BoonWeb.LiveUserAuth, :live_no_user}]
    sign_out_route AuthController
    auth_routes AuthController, Boon.Accounts.User, path: "/auth"
  end

  scope "/", BoonWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/shipments/:id/packing-slip", ShipmentPackingSlipController, :show

    live_session :authenticated,
      on_mount: [
        AshAuthentication.Phoenix.LiveSession,
        {BoonWeb.LiveUserAuth, :live_user_required}
      ],
      session: {BoonWeb.LiveUserAuth, :generate_authenticated_session, []} do
      live "/", DashboardLive
      live "/intake", IntakeLive
      live "/work-packages", WorkPackageLive.Index

      live "/work-packages/:work_package_id/purchase-orders/:purchase_order_id",
           WorkPackageLive.PurchaseOrderShow

      live "/work-packages/:id", WorkPackageLive.Show
      live "/shipments", ShipmentLive.Index
      live "/shipments/:id", ShipmentLive.Show
      live "/ship", ShipLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BoonWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:boon, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: BoonWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  defp ensure_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_session(:return_to, current_path(conn))
      |> redirect(to: "/sign-in")
      |> halt()
    end
  end
end
