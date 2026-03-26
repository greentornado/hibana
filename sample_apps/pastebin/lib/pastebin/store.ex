defmodule Pastebin.Store do
  @table :pastebin_pastes

  def create(params) do
    id = generate_id()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    expires_in = Map.get(params, :expires_in) || Map.get(params, "expires_in")

    seconds =
      cond do
        is_integer(expires_in) -> expires_in
        is_binary(expires_in) and expires_in != "never" ->
          case Integer.parse(expires_in) do
            {n, _} -> n
            :error -> nil
          end
        true -> nil
      end

    expires_at =
      if seconds && seconds > 0 do
        DateTime.utc_now() |> DateTime.add(seconds) |> DateTime.to_iso8601()
      else
        nil
      end

    paste = %{
      id: id,
      content: Map.get(params, :content) || Map.get(params, "content", ""),
      title: Map.get(params, :title) || Map.get(params, "title", "Untitled"),
      language: Map.get(params, :language) || Map.get(params, "language", "text"),
      created_at: now,
      expires_at: expires_at,
      private: Map.get(params, :private) || Map.get(params, "private", false),
      view_count: 0
    }

    :ets.insert(@table, {id, paste})
    {:ok, paste}
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, paste}] ->
        if expired?(paste) do
          :ets.delete(@table, id)
          :not_found
        else
          {:ok, paste}
        end

      [] ->
        :not_found
    end
  end

  # Note: concurrent views may lose counts due to read-modify-write race condition.
  # For production, serialize through a GenServer or use a different ETS structure
  # with :ets.update_counter.
  def get_and_increment_views(id) do
    case get(id) do
      {:ok, paste} ->
        updated = %{paste | view_count: paste.view_count + 1}
        :ets.insert(@table, {id, updated})
        {:ok, updated}

      :not_found ->
        :not_found
    end
  end

  def list_recent(limit \\ 20) do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, paste} -> paste end)
    |> Enum.reject(& &1.private)
    |> Enum.reject(&expired?/1)
    |> Enum.sort_by(& &1.created_at, :desc)
    |> Enum.take(limit)
  end

  def delete(id) do
    :ets.delete(@table, id)
    :ok
  end

  def cleanup_expired do
    now = DateTime.utc_now()

    :ets.tab2list(@table)
    |> Enum.each(fn {id, paste} ->
      if expired?(paste, now), do: :ets.delete(@table, id)
    end)
  end

  defp expired?(paste, now \\ DateTime.utc_now()) do
    case paste.expires_at do
      nil -> false
      expires_at_str ->
        case DateTime.from_iso8601(expires_at_str) do
          {:ok, expires_at, _} -> DateTime.compare(now, expires_at) == :gt
          _ -> false
        end
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.url_encode64(padding: false) |> binary_part(0, 8)
  end
end
