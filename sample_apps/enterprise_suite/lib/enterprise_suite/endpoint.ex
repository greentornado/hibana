defmodule EnterpriseSuite.Endpoint do
  use Hibana.Endpoint, otp_app: :enterprise_suite

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug EnterpriseSuite.Router
end
