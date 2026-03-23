defmodule BackgroundJobs.Endpoint do
  use Hibana.Endpoint, otp_app: :background_jobs

  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.Logger)
  plug BackgroundJobs.Router
end
