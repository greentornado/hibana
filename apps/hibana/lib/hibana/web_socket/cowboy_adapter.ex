defmodule Hibana.WebSocket.CowboyAdapter do
  @moduledoc """
  Bridges Hibana.WebSocket callbacks to Cowboy's cowboy_websocket behavior.

  This module is used internally by `Hibana.WebSocket.upgrade/3`.
  Users should not interact with it directly.
  """

  @behaviour :cowboy_websocket

  @impl true
  def init(req, {handler, handler_opts}) do
    # Build a minimal conn-like map for the handler's init callback
    conn = Plug.Cowboy.Conn.conn(req)
    conn = Plug.Conn.fetch_query_params(conn)

    try do
      case handler.init(conn, handler_opts) do
        {:ok, _conn, state} ->
          {:cowboy_websocket, req, %{handler: handler, state: state}}

        {:halt, _conn} ->
          req = :cowboy_req.reply(403, req)
          {:ok, req, %{}}

        other ->
          require Logger
          Logger.error("[WebSocket] Handler init returned invalid response: #{inspect(other)}")

          req =
            :cowboy_req.reply(
              500,
              %{"content-type" => "text/plain"},
              "Invalid WebSocket handler response",
              req
            )

          {:ok, req, %{}}
      end
    rescue
      e ->
        require Logger
        Logger.error("[WebSocket] Handler init crashed: #{inspect(e)}")

        req =
          :cowboy_req.reply(
            500,
            %{"content-type" => "text/plain"},
            "WebSocket handler error",
            req
          )

        {:ok, req, %{}}
    end
  end

  @impl true
  def websocket_init(state) do
    handler = state.handler

    case handler.handle_connect(%{}, state.state) do
      {:ok, new_state} ->
        {[], %{state | state: new_state}}

      {:stop, new_state} ->
        {[{:close, 1000, ""}], %{state | state: new_state}}
    end
  end

  @impl true
  def websocket_handle({:text, message}, state) do
    handler = state.handler

    case handler.handle_in(message, state.state) do
      {:ok, new_state} ->
        {[], %{state | state: new_state}}

      {:reply, {:text, text}, new_state} ->
        {[{:text, text}], %{state | state: new_state}}

      {:reply, {:binary, bin}, new_state} ->
        {[{:binary, bin}], %{state | state: new_state}}

      {:stop, new_state} ->
        {[{:close, 1000, ""}], %{state | state: new_state}}
    end
  end

  def websocket_handle({:binary, message}, state) do
    handler = state.handler

    case handler.handle_binary(message, state.state) do
      {:ok, new_state} ->
        {[], %{state | state: new_state}}

      {:reply, {:text, text}, new_state} ->
        {[{:text, text}], %{state | state: new_state}}

      {:reply, {:binary, bin}, new_state} ->
        {[{:binary, bin}], %{state | state: new_state}}

      {:stop, new_state} ->
        {[{:close, 1000, ""}], %{state | state: new_state}}
    end
  end

  def websocket_handle({:ping, _}, state) do
    {[{:pong, ""}], state}
  end

  def websocket_handle(_frame, state) do
    {[], state}
  end

  @impl true
  def websocket_info(message, state) do
    handler = state.handler

    case handler.handle_info(message, state.state) do
      {:ok, new_state} ->
        {[], %{state | state: new_state}}

      {:push, {:text, text}, new_state} ->
        {[{:text, text}], %{state | state: new_state}}

      {:push, {:binary, bin}, new_state} ->
        {[{:binary, bin}], %{state | state: new_state}}

      {:stop, new_state} ->
        {[{:close, 1000, ""}], %{state | state: new_state}}
    end
  end

  @impl true
  def terminate(reason, _req, state) do
    if Map.has_key?(state, :handler) do
      state.handler.handle_disconnect(reason, state.state)
    end

    :ok
  end
end
