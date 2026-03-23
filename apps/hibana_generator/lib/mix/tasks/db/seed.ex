defmodule Mix.Tasks.Db.Seed do
  @moduledoc """
  Mix task to run database seeds from `priv/seeds.exs`.

  ## Usage

      mix db.seed
      mix db.seed --file priv/custom_seeds.exs
  """

  use Mix.Task

  @shortdoc "Run database seeds"

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [file: :string])

    # Start the application
    Mix.Task.run("app.start")

    seed_file = Keyword.get(opts, :file, "priv/seeds.exs")

    if File.exists?(seed_file) do
      Mix.shell().info("Running seeds from #{seed_file}...")

      start = System.monotonic_time(:millisecond)
      Code.eval_file(seed_file)
      elapsed = System.monotonic_time(:millisecond) - start

      Mix.shell().info("Seeds completed in #{elapsed}ms.")
    else
      Mix.shell().error("Seed file not found: #{seed_file}")
      Mix.shell().info("Create #{seed_file} to get started.")
    end
  end
end

defmodule Hibana.Faker do
  @moduledoc """
  Simple fake data generator for seeding and testing.

  ## Usage

      Hibana.Faker.name()        # => "Alice Johnson"
      Hibana.Faker.email()       # => "bob.smith42@example.com"
      Hibana.Faker.phone()       # => "+1-555-123-4567"
      Hibana.Faker.uuid()        # => "550e8400-e29b-41d4-a716-446655440000"
      Hibana.Faker.sentence()    # => "The quick brown fox jumps."
      Hibana.Faker.paragraph()   # => Multiple sentences...
      Hibana.Faker.integer(1, 100) # => 42
      Hibana.Faker.boolean()     # => true
      Hibana.Faker.pick(list)    # => random element
      Hibana.Faker.sequence("user") # => "user_1", "user_2", ...
  """

  @first_names ~w(Alice Bob Charlie Diana Eve Frank Grace Henry Iris Jack Kate Leo
    Mia Noah Olivia Peter Quinn Rose Sam Tina Uma Victor Wendy Xavier Yara Zane)

  @last_names ~w(Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez
    Martinez Hernandez Lopez Wilson Anderson Thomas Taylor Moore Jackson Martin Lee)

  @domains ~w(example.com test.org demo.net mail.io inbox.dev)

  @words ~w(the a an is was were been being have has had do does did will would
    shall should may might can could of in to for with on at by from as into
    through during before after above below between out off over under again
    further then once here there when where why how all each every both few
    more most other some such no nor not only own same so than too very just
    about also back even still well almost already always among another any
    around away enough far first got great help high however keep last long
    made make many much must never new next now old part place point put
    right seem set small something state still take tell think turn use want
    work world year)

  @doc "Generate a random full name."
  def name do
    "#{pick(@first_names)} #{pick(@last_names)}"
  end

  @doc "Generate a random email address."
  def email do
    first = pick(@first_names) |> String.downcase()
    last = pick(@last_names) |> String.downcase()
    num = :rand.uniform(999)
    domain = pick(@domains)
    "#{first}.#{last}#{num}@#{domain}"
  end

  @doc "Generate a random phone number."
  def phone do
    area = :rand.uniform(899) + 100
    prefix = :rand.uniform(899) + 100
    line = :rand.uniform(8999) + 1000
    "+1-#{area}-#{prefix}-#{line}"
  end

  @doc "Generate a random UUID v4."
  def uuid do
    import Bitwise

    <<a::32, b::16, _::4, c::12, _::2, d::62>> = :crypto.strong_rand_bytes(16)

    [
      Integer.to_string(a, 16) |> String.pad_leading(8, "0"),
      Integer.to_string(b, 16) |> String.pad_leading(4, "0"),
      Integer.to_string(bor(0x4000, c), 16) |> String.pad_leading(4, "0"),
      Integer.to_string(bor(0x8000_0000_0000_0000, d), 16)
      |> String.pad_leading(16, "0")
      |> then(fn s -> String.slice(s, 0, 4) <> "-" <> String.slice(s, 4, 12) end)
    ]
    |> Enum.join("-")
    |> String.downcase()
  end

  @doc "Generate a random date in the past year."
  def date do
    days_ago = :rand.uniform(365)
    Date.utc_today() |> Date.add(-days_ago)
  end

  @doc "Generate a random datetime in the past year."
  def datetime do
    seconds_ago = :rand.uniform(365 * 24 * 3600)
    DateTime.utc_now() |> DateTime.add(-seconds_ago, :second)
  end

  @doc "Generate a random sentence."
  def sentence do
    word_count = :rand.uniform(8) + 4

    words =
      1..word_count
      |> Enum.map(fn _ -> pick(@words) end)

    first = words |> List.first() |> String.capitalize()
    rest = words |> Enum.drop(1)

    ([first | rest] |> Enum.join(" ")) <> "."
  end

  @doc "Generate a random paragraph (3-6 sentences)."
  def paragraph do
    count = :rand.uniform(4) + 2

    1..count
    |> Enum.map(fn _ -> sentence() end)
    |> Enum.join(" ")
  end

  @doc "Generate a random integer between min and max (inclusive)."
  def integer(min \\ 0, max \\ 1000) do
    min + :rand.uniform(max - min + 1) - 1
  end

  @doc "Generate a random boolean."
  def boolean do
    :rand.uniform(2) == 1
  end

  @doc "Pick a random element from a list."
  def pick(list) when is_list(list) and length(list) > 0 do
    Enum.random(list)
  end

  @doc """
  Generate a sequential value with a prefix.
  Uses the process dictionary to track the counter.
  """
  def sequence(prefix) do
    key = {:faker_sequence, prefix}
    current = Process.get(key, 0)
    next = current + 1
    Process.put(key, next)
    "#{prefix}_#{next}"
  end
end
