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
    {title, link, subtitle} = case HTTPoison.get("https://www.bmwi.de/SiteGlobals/BMWI/Forms/Listen/Parlamentarische-Anfragen/Parlamentarische-Anfragen_Formular.html") do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> process_html(body)
      _ -> {"Nothing", "Now"}
    end

    message = "*#{title}*\n\n#{subtitle}\n\nhttps://www.bmwi.de#{link}"
    Nadia.send_message(update.message.chat.id, message, parse_mode: "Markdown")
  end

  defp process_html(body) do
    {:ok, document} = Floki.parse_document(body)

    case Floki.find(document, ".card-list-item .card") do
      [head | _tail] -> process_card(head)
    end
  end

  defp process_card(card) do
    title = case Floki.find([card], ".card-title .card-title-label") do
      [{_tag, _attrs, [title]} | _tail] -> title
    end

    link = case Floki.find([card], ".card-link-overlay") do
      f -> Floki.attribute(f, "href")
    end

    subtitle = case Floki.find([card], ".card-subtitle") do
      f -> Floki.text(f) |> String.trim
    end

    {title, link, subtitle}
  end
end
