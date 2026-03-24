# `Hibana.Job`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/job.ex#L1)

Background job queue module using OTP.

## Usage

    defmodule MyJob do
      use Hibana.Job

      def perform(data) do
        IO.inspect(data, label: "Processing job")
      end
    end

    # Enqueue a job
    MyJob.enqueue(%{user_id: 123, action: "send_email"})

---

*Consult [api-reference.md](api-reference.md) for complete listing*
