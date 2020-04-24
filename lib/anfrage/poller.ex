defmodule Anfrage.Poller do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, 0, opts)
  end

  @impl true
  def init(offset) do
    schedule()
    {:ok, offset}
  end

  @impl true
  def handle_info(:get, offset) do
    new_offset = get(offset)
    schedule()
    {:noreply, new_offset}
  end

  def get(offset) do
    case Nadia.get_updates(offset: offset) do
      {:ok, []} ->
        offset

      {:ok, updates} ->
        handle_updates(updates)
        List.last(updates).update_id + 1

      {:error, _} ->
        offset
    end
  end

  defp schedule do
    send(self(), :get)
  end

  defp handle_updates(updates) do
    # handle messages off process
    Task.Supervisor.start_child(
      Anfrage.TaskSupervisor,
      fn -> process_updates(updates) end
    )
  end

  defp process_updates(updates) do
    Enum.each(updates, &process_update(&1))
  end

  defp process_update(update) do
    # For now just echo back
    Nadia.send_message(update.message.chat.id, update.message.text)
  end
end
