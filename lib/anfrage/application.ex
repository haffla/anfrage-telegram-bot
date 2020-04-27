defmodule Anfrage.Application do
  use Application

  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4000")
    children = [
      {Plug.Cowboy, scheme: :http, plug: Anfrage.Server, port: port},
      # Task Supervisor used for spawning message handler processes
      {Task.Supervisor, name: Anfrage.TaskSupervisor},
      {Anfrage.Poller, name: Anfrage.Poller}
    ]

    opts = [strategy: :one_for_one, name: Anfrage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
