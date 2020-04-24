defmodule Anfrage.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Task Supervisor used for spawning message handler processes
      {Task.Supervisor, name: Anfrage.TaskSupervisor},
      {Anfrage.Poller, name: Anfrage.Poller}
    ]

    opts = [strategy: :one_for_one, name: Anfrage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
