defmodule LivePoll.PollStore do
  use GenServer

  @table :polls

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    seed_data()
    {:ok, %{}}
  end

  def create(question, options, opts \\ []) do
    id = generate_id()
    multiple = Keyword.get(opts, :multiple, false)
    expires_in = Keyword.get(opts, :expires_in, nil)

    now = System.system_time(:second)
    expires_at = if expires_in, do: now + expires_in, else: nil

    votes = options |> Enum.with_index() |> Enum.map(fn {_, i} -> {i, 0} end) |> Map.new()

    poll = %{
      id: id,
      question: question,
      options: options,
      votes: votes,
      voters: MapSet.new(),
      multiple: multiple,
      created_at: now,
      expires_at: expires_at
    }

    :ets.insert(@table, {id, poll})
    {:ok, poll}
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, poll}] -> {:ok, poll}
      [] -> {:error, :not_found}
    end
  end

  def list do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, poll} -> poll end)
    |> Enum.sort_by(& &1.created_at, :desc)
  end

  def vote(poll_id, option_index, voter_ip) do
    case get(poll_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, poll} ->
        now = System.system_time(:second)

        cond do
          poll.expires_at != nil and now > poll.expires_at ->
            {:error, :expired}

          not poll.multiple and MapSet.member?(poll.voters, voter_ip) ->
            {:error, :already_voted}

          option_index < 0 or option_index >= length(poll.options) ->
            {:error, :invalid_option}

          true ->
            new_votes = Map.update!(poll.votes, option_index, &(&1 + 1))
            new_voters = MapSet.put(poll.voters, voter_ip)
            updated = %{poll | votes: new_votes, voters: new_voters}
            :ets.insert(@table, {poll_id, updated})
            {:ok, updated}
        end
    end
  end

  def expired?(poll) do
    poll.expires_at != nil and System.system_time(:second) > poll.expires_at
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false)
  end

  defp seed_data do
    # Poll 1: Best programming language
    id1 = "poll_lang"

    poll1 = %{
      id: id1,
      question: "Best programming language?",
      options: ["Elixir", "Rust", "Go", "Python"],
      votes: %{0 => 42, 1 => 38, 2 => 25, 3 => 31},
      voters: MapSet.new(["seed1", "seed2", "seed3", "seed4"]),
      multiple: false,
      created_at: System.system_time(:second) - 3600,
      expires_at: nil
    }

    :ets.insert(@table, {id1, poll1})

    # Poll 2: Favorite framework
    id2 = "poll_fw"

    poll2 = %{
      id: id2,
      question: "Favorite framework?",
      options: ["Phoenix", "Hibana", "Rails", "Django"],
      votes: %{0 => 35, 1 => 48, 2 => 22, 3 => 19},
      voters: MapSet.new(["seed5", "seed6", "seed7", "seed8"]),
      multiple: false,
      created_at: System.system_time(:second) - 1800,
      expires_at: nil
    }

    :ets.insert(@table, {id2, poll2})
  end
end
