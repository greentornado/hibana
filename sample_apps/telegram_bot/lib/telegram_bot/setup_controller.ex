defmodule TelegramBot.SetupController do
  use Hibana.Controller

  def setup(conn) do
    token = conn.params["token"]
    url = conn.params["url"]

    cond do
      is_nil(token) or token == "" ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing 'token' query parameter"})

      is_nil(url) or url == "" ->
        conn
        |> put_status(400)
        |> json(%{error: "Missing 'url' query parameter"})

      true ->
        case TelegramBot.TelegramApi.set_webhook(token, url) do
          {:ok, status, resp_body} ->
            body =
              case Jason.decode(resp_body) do
                {:ok, decoded} -> decoded
                _ -> %{raw: resp_body}
              end

            json(conn, %{
              webhook_set: true,
              telegram_status: status,
              telegram_response: body
            })

          {:error, reason} ->
            conn
            |> put_status(502)
            |> json(%{error: "Failed to set webhook", reason: inspect(reason)})
        end
    end
  end

  def status(conn) do
    configured_token = Application.get_env(:telegram_bot, :bot_token, "test-token")
    message_count = TelegramBot.MessageLog.count()

    bot_info =
      case TelegramBot.TelegramApi.get_me(configured_token) do
        {:ok, 200, resp_body} ->
          case Jason.decode(resp_body) do
            {:ok, %{"result" => result}} -> result
            _ -> %{error: "Could not parse bot info"}
          end

        {:ok, status, _} ->
          %{error: "Telegram API returned status #{status}"}

        {:error, reason} ->
          %{error: "Could not reach Telegram API: #{inspect(reason)}"}
      end

    json(conn, %{
      app: "telegram_bot",
      status: "running",
      port: 4013,
      bot_info: bot_info,
      recent_messages_count: message_count,
      endpoints: %{
        webhook: "POST /webhook/:token",
        setup: "GET /setup?token=BOT_TOKEN&url=WEBHOOK_URL",
        status: "GET /status",
        health: "GET /health",
        messages: "GET /messages"
      }
    })
  end

  def messages(conn) do
    limit =
      case conn.params["limit"] do
        nil -> 20
        val ->
          case Integer.parse(val) do
            {n, _} -> n
            :error -> 20
          end
      end

    messages = TelegramBot.MessageLog.recent(limit)
    json(conn, %{messages: messages, count: length(messages)})
  end
end
