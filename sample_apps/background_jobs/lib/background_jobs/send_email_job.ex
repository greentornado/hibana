defmodule BackgroundJobs.SendEmailJob do
  use Hibana.Queue.Job

  def perform(data) do
    IO.puts("========================================")
    IO.puts("SENDING EMAIL")
    IO.puts("To: #{data[:to] || data["to"]}")
    IO.puts("Subject: #{data[:subject] || data["subject"]}")
    IO.puts("Body: #{data[:body] || data["body"]}")
    IO.puts("Sent at: #{DateTime.utc_now()}")
    IO.puts("========================================")
    :ok
  end
end
