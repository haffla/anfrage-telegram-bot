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
    Nadia.send_chat_action(update.message.chat.id, "typing")

    search =
      case update.message.text do
        "/neu" -> ""
        s -> s
      end

    case request(search) do
      {title, link, subtitle, date} ->
        link = "https://www.bmwi.de#{link}"
        message = "#{date}\n\n#{title}\n\n#{subtitle}\n\n#{link}"
        Nadia.send_message(update.message.chat.id, message)

      {:error, :empty} ->
        Nadia.send_message(update.message.chat.id, "#{search}? Nein!")

      {:error, :http} ->
        Nadia.send_message(
          update.message.chat.id,
          "Es gab ein Fehler. Probieren Sie es bitte erneut!"
        )
    end
  end

  defp request(search) do
    case HTTPoison.get(
           "https://www.bmwi.de/SiteGlobals/BMWI/Forms/Listen/Parlamentarische-Anfragen/Parlamentarische-Anfragen_Formular.html?templateQueryStringListen=#{
             search
           }"
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> process_html(body)
      _ -> {:error, :http}
    end
  end

  defp process_html(body) do
    {:ok, document} = Floki.parse_document(body)

    case Floki.find(document, ".card-list-item .card") do
      [{_tag, _attrs, children} | _tail] -> process_card(children)
      _ -> {:error, :empty}
    end
  end

  defp process_card(card) do
    subtitle = Floki.find(card, ".card-subtitle") |> Floki.text() |> String.trim()
    title = Floki.find(card, ".card-title .card-title-label") |> Floki.text() |> String.trim()
    date = Floki.find(card, ".card-topline .date") |> Floki.text() |> String.trim()
    link = Floki.find(card, ".card-link-overlay") |> Floki.attribute("href")

    {title, link, subtitle, date}
  end
end
