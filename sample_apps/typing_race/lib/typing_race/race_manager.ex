defmodule TypingRace.RaceManager do
  def create_race(max_players \\ 4) do
    code = generate_code()

    case DynamicSupervisor.start_child(
           TypingRace.RaceSupervisor,
           {TypingRace.RaceServer, code: code, max_players: max_players}
         ) do
      {:ok, _pid} -> {:ok, code}
      {:error, reason} -> {:error, reason}
    end
  end

  def race_exists?(code) do
    case Registry.lookup(TypingRace.RaceRegistry, code) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp generate_code do
    code =
      1..4
      |> Enum.map(fn _ -> Enum.random(0..9) end)
      |> Enum.join("")

    if race_exists?(code), do: generate_code(), else: code
  end
end
