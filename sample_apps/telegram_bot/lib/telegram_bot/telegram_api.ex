defmodule TelegramBot.TelegramApi do
  @moduledoc """
  Telegram Bot API client using hackney for HTTP requests.
  """

  @base_url "https://api.telegram.org/bot"

  def send_message(token, chat_id, text) do
    url = "#{@base_url}#{token}/sendMessage"
    body = Jason.encode!(%{chat_id: chat_id, text: text, parse_mode: "HTML"})

    case :hackney.request(:post, url, [{"content-type", "application/json"}], body, [:with_body]) do
      {:ok, status, _headers, resp_body} -> {:ok, status, resp_body}
      {:error, reason} -> {:error, reason}
    end
  end

  def send_message_with_keyboard(token, chat_id, text, keyboard) do
    url = "#{@base_url}#{token}/sendMessage"

    body =
      Jason.encode!(%{
        chat_id: chat_id,
        text: text,
        parse_mode: "HTML",
        reply_markup: %{inline_keyboard: keyboard}
      })

    case :hackney.request(:post, url, [{"content-type", "application/json"}], body, [:with_body]) do
      {:ok, status, _headers, resp_body} -> {:ok, status, resp_body}
      {:error, reason} -> {:error, reason}
    end
  end

  def answer_callback_query(token, callback_query_id, text \\ nil) do
    url = "#{@base_url}#{token}/answerCallbackQuery"

    payload = %{callback_query_id: callback_query_id}
    payload = if text, do: Map.put(payload, :text, text), else: payload
    body = Jason.encode!(payload)

    case :hackney.request(:post, url, [{"content-type", "application/json"}], body, [:with_body]) do
      {:ok, status, _headers, resp_body} -> {:ok, status, resp_body}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_webhook(token, webhook_url) do
    url = "#{@base_url}#{token}/setWebhook"
    body = Jason.encode!(%{url: webhook_url})

    case :hackney.request(:post, url, [{"content-type", "application/json"}], body, [:with_body]) do
      {:ok, status, _headers, resp_body} -> {:ok, status, resp_body}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_me(token) do
    url = "#{@base_url}#{token}/getMe"

    case :hackney.request(:get, url, [], <<>>, [:with_body]) do
      {:ok, status, _headers, resp_body} -> {:ok, status, resp_body}
      {:error, reason} -> {:error, reason}
    end
  end
end
