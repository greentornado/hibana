defmodule LivePoll.ApiController do
  use Hibana.Controller

  def health(conn) do
    json(conn, %{status: "ok", app: "live_poll", port: 4032})
  end

  def list_polls(conn) do
    polls =
      LivePoll.PollStore.list()
      |> Enum.map(&sanitize_poll/1)

    json(conn, %{polls: polls, total: length(polls)})
  end

  def create_poll(conn) do
    body = conn.body_params
    question = Map.get(body, "question", "")
    options = Map.get(body, "options", [])
    multiple = Map.get(body, "multiple", false)
    expires_in = Map.get(body, "expires_in")

    cond do
      String.trim(question) == "" ->
        put_status(conn, 400) |> json(%{error: "Question is required"})

      not is_list(options) or length(options) < 2 ->
        put_status(conn, 400) |> json(%{error: "At least 2 options are required"})

      true ->
        opts = [multiple: multiple]
        opts = if expires_in, do: Keyword.put(opts, :expires_in, expires_in), else: opts

        {:ok, poll} = LivePoll.PollStore.create(question, options, opts)
        put_status(conn, 201) |> json(%{poll: sanitize_poll(poll)})
    end
  end

  def get_poll(conn) do
    id = conn.params["id"]

    case LivePoll.PollStore.get(id) do
      {:ok, poll} -> json(conn, %{poll: sanitize_poll(poll)})
      {:error, :not_found} -> put_status(conn, 404) |> json(%{error: "Poll not found"})
    end
  end

  def vote(conn) do
    id = conn.params["id"]
    body = conn.body_params
    option_index = Map.get(body, "option")
    voter_ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    cond do
      option_index == nil ->
        put_status(conn, 400) |> json(%{error: "Option index is required"})

      not is_integer(option_index) ->
        put_status(conn, 400) |> json(%{error: "Option must be an integer"})

      true ->
        case LivePoll.PollStore.vote(id, option_index, voter_ip) do
          {:ok, poll} ->
            counts = vote_counts(poll)
            total = Enum.sum(counts)

            LivePoll.PollNotifier.broadcast(id, "vote", %{
              option: option_index,
              counts: counts,
              total: total
            })

            # Check if poll just expired
            if LivePoll.PollStore.expired?(poll) do
              winner_idx = counts |> Enum.with_index() |> Enum.max_by(fn {c, _} -> c end) |> elem(1)
              winner = Enum.at(poll.options, winner_idx)

              LivePoll.PollNotifier.broadcast(id, "poll_closed", %{
                winner: winner,
                counts: counts
              })
            end

            json(conn, %{
              success: true,
              counts: counts,
              total: total
            })

          {:error, :not_found} ->
            put_status(conn, 404) |> json(%{error: "Poll not found"})

          {:error, :expired} ->
            put_status(conn, 410) |> json(%{error: "Poll has expired"})

          {:error, :already_voted} ->
            put_status(conn, 409) |> json(%{error: "Already voted"})

          {:error, :invalid_option} ->
            put_status(conn, 400) |> json(%{error: "Invalid option index"})
        end
    end
  end

  def stream(conn) do
    id = conn.params["id"]

    case LivePoll.PollStore.get(id) do
      {:error, :not_found} ->
        put_status(conn, 404) |> json(%{error: "Poll not found"})

      {:ok, poll} ->
        LivePoll.PollNotifier.subscribe(id)

        conn = Hibana.SSE.init(conn)

        # Send initial state
        counts = vote_counts(poll)

        {:ok, conn} =
          Hibana.SSE.send_event(conn, "init", %{
            counts: counts,
            total: Enum.sum(counts)
          })

        # Loop receiving events
        Hibana.SSE.stream_loop(conn, keep_alive: 15_000)
    end
  end

  defp sanitize_poll(poll) do
    counts = vote_counts(poll)

    %{
      id: poll.id,
      question: poll.question,
      options: poll.options,
      counts: counts,
      total: Enum.sum(counts),
      multiple: poll.multiple,
      created_at: poll.created_at,
      expires_at: poll.expires_at,
      expired: LivePoll.PollStore.expired?(poll)
    }
  end

  defp vote_counts(poll) do
    0..(length(poll.options) - 1)
    |> Enum.map(fn i -> Map.get(poll.votes, i, 0) end)
  end
end
