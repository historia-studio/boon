defmodule Boon.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BoonWeb.Telemetry,
      Boon.Repo,
      {DNSCluster, query: Application.get_env(:boon, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Boon.PubSub},
      # Start a worker by calling: Boon.Worker.start_link(arg)
      # {Boon.Worker, arg},
      # Start to serve requests, typically the last entry
      BoonWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Boon.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BoonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
