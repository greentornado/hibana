defmodule TelegramBot.Bot do
  @moduledoc """
  Bot logic: parses incoming Telegram updates and generates responses.
  Returns {chat_id, response} tuples or :ignore.
  """

  def handle_update(update) do
    cond do
      update["message"] -> handle_message(update["message"])
      update["callback_query"] -> handle_callback(update["callback_query"])
      true -> :ignore
    end
  end

  defp handle_message(message) do
    text = message["text"] || ""
    chat_id = get_in(message, ["chat", "id"])

    cond do
      String.starts_with?(text, "/start") ->
        {chat_id,
         "Welcome! I'm a Hibana-powered Telegram bot.\nUse /help to see available commands."}

      String.starts_with?(text, "/help") ->
        help_text = """
        Available commands:
        /start - Welcome message
        /help - Show this help
        /echo <text> - Echo back your text
        /time - Current UTC time
        /dice - Roll a dice (1-6)
        /weather <city> - Weather info (demo)
        /menu - Show inline keyboard
        """

        {chat_id, String.trim(help_text)}

      String.starts_with?(text, "/echo ") ->
        echo_text = String.replace_prefix(text, "/echo ", "")
        {chat_id, echo_text}

      text == "/echo" ->
        {chat_id, "Usage: /echo <text>"}

      String.starts_with?(text, "/time") ->
        now = DateTime.utc_now() |> DateTime.to_string()
        {chat_id, "Current UTC time: #{now}"}

      String.starts_with?(text, "/dice") ->
        roll = :rand.uniform(6)
        {chat_id, "You rolled: #{roll}"}

      String.starts_with?(text, "/weather ") ->
        city = String.replace_prefix(text, "/weather ", "")
        temp = :rand.uniform(35)
        humidity = :rand.uniform(100)

        {chat_id,
         "Weather in #{city} (demo):\nTemperature: #{temp}C\nHumidity: #{humidity}%\nCondition: Sunny"}

      text == "/weather" ->
        {chat_id, "Usage: /weather <city>"}

      String.starts_with?(text, "/menu") ->
        {chat_id, :menu}

      String.starts_with?(text, "/") ->
        {chat_id, "Unknown command. Try /help"}

      true ->
        {chat_id, "I received: #{text}\nUse /help to see available commands."}
    end
  end

  defp handle_callback(callback_query) do
    chat_id = get_in(callback_query, ["message", "chat", "id"])
    data = callback_query["data"]
    callback_id = callback_query["id"]

    # Answer the callback query to dismiss the loading indicator
    token = Application.get_env(:telegram_bot, :bot_token, "test-token")
    TelegramBot.TelegramApi.answer_callback_query(token, callback_id, "Received!")

    response =
      case data do
        "opt_1" -> "You selected Option 1!"
        "opt_2" -> "You selected Option 2!"
        "opt_help" -> "Use /help to see all available commands."
        _ -> "Unknown option: #{data}"
      end

    {chat_id, response}
  end
end
