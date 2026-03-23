defmodule TelegramBot.WebhookController do
  use Hibana.Controller

  def webhook(conn) do
    token = conn.params["token"]
    configured_token = Application.get_env(:telegram_bot, :bot_token, "test-token")

    if token != configured_token do
      conn |> put_status(403) |> json(%{error: "Invalid token"})
    else
      update = conn.body_params
      TelegramBot.MessageLog.log(update)

      case TelegramBot.Bot.handle_update(update) do
        {chat_id, :menu} ->
          keyboard = [
            [
              %{text: "Option 1", callback_data: "opt_1"},
              %{text: "Option 2", callback_data: "opt_2"}
            ],
            [
              %{text: "Help", callback_data: "opt_help"}
            ]
          ]

          TelegramBot.TelegramApi.send_message_with_keyboard(
            token,
            chat_id,
            "Choose an option:",
            keyboard
          )

          json(conn, %{ok: true})

        {chat_id, text} ->
          TelegramBot.TelegramApi.send_message(token, chat_id, text)
          json(conn, %{ok: true})

        :ignore ->
          json(conn, %{ok: true})
      end
    end
  end
end
