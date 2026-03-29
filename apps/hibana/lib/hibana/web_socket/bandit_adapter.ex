defmodule Hibana.WebSocket.BanditAdapter do
  @moduledoc """
  Bridges Hibana.WebSocket callbacks to Bandit's WebSocket support.

  This module is used internally by `Hibana.WebSocket.upgrade/3` when
  the application is using Bandit as the HTTP server.

  Bandit provides native WebSocket support with a clean, Elixir-friendly API.

  ## Usage

  This adapter is automatically selected when using `Hibana.BanditEndpoint`.
  For Cowboy, use `Hibana.WebSocket.CowboyAdapter` instead.
  """

  @behaviour WebSock

  @impl true
  def init({handler, handler_opts}) do
    # Initialize the WebSocket connection
    init_state = %{
      handler: handler,
      handler_opts: handler_opts,
      state: nil
    }

    try do
      # Call handler's init
      case handler.init(%{}, handler_opts) do
        {:ok, _conn, handler_state} ->
          state = %{init_state | state: handler_state}

          # Notify handler of connection
          case handler.handle_connect(%{}, handler_state) do
            {:ok, new_state} ->
              {:ok, %{state | state: new_state}}

            {:stop, _new_state} ->
              {:stop, :normal, state}
          end

        {:halt, _conn} ->
          {:stop, :normal, init_state}
      end
    rescue
      e ->
        require Logger
        Logger.error("[WebSocket] Handler init crashed: #{inspect(e)}")
        {:stop, :normal, init_state}
    end
  end

  @impl true
  def handle_in({:text, message}, state) do
    handler = state.handler

    case handler.handle_in(message, state.state) do
      {:ok, new_state} ->
        {:ok, %{state | state: new_state}}

      {:reply, {:text, text}, new_state} ->
        {:reply, {:text, text}, %{state | state: new_state}}

      {:reply, {:binary, bin}, new_state} ->
        {:reply, {:binary, bin}, %{state | state: new_state}}

      {:stop, new_state} ->
        {:stop, :normal, %{state | state: new_state}}

      invalid ->
        require Logger
        Logger.error("[WebSocket] Invalid handle_in response: #{inspect(invalid)}")
        {:stop, :normal, state}
    end
  end

  def handle_in({:binary, message}, state) do
    handler = state.handler

    case handler.handle_binary(message, state.state) do
      {:ok, new_state} ->
        {:ok, %{state | state: new_state}}

      {:reply, {:text, text}, new_state} ->
        {:reply, {:text, text}, %{state | state: new_state}}

      {:reply, {:binary, bin}, new_state} ->
        {:reply, {:binary, bin}, %{state | state: new_state}}

      {:stop, new_state} ->
        {:stop, :normal, %{state | state: new_state}}

      invalid ->
        require Logger
        Logger.error("[WebSocket] Invalid handle_binary response: #{inspect(invalid)}")
        {:stop, :normal, state}
    end
  end

  # Handle ping frames - respond with pong for keepalive
  def handle_in({:ping, data}, state) do
    {:reply, {:pong, data}, state}
  end

  # Handle pong frames - just acknowledge
  def handle_in({:pong, _data}, state) do
    {[], state}
  end

  def handle_in(_frame, state) do
    {[], state}
  end

  @impl true
  def handle_info(message, state) do
    handler = state.handler

    case handler.handle_info(message, state.state) do
      {:ok, new_state} ->
        {:ok, %{state | state: new_state}}

      {:push, {:text, text}, new_state} ->
        {:push, {:text, text}, %{state | state: new_state}}

      {:push, {:binary, bin}, new_state} ->
        {:push, {:binary, bin}, %{state | state: new_state}}

      {:stop, new_state} ->
        {:stop, :normal, %{state | state: new_state}}
    end
  end

  @impl true
  def terminate(reason, state) do
    if Map.has_key?(state, :handler) and Map.has_key?(state, :state) do
      state.handler.handle_disconnect(reason, state.state)
    end

    :ok
  end
end
