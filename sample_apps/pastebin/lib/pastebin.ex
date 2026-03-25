defmodule Pastebin do
  use Application

  @impl true
  def start(_type, _args) do
    :ets.new(:pastebin_pastes, [:named_table, :set, :public])

    Hibana.Plugins.I18n.put_translations("en", %{
      "create_paste" => "Create Paste",
      "view_paste" => "View Paste",
      "not_found" => "Paste not found",
      "expires_in" => "Expires in",
      "never" => "Never",
      "views" => "Views",
      "raw" => "Raw",
      "copy" => "Copy",
      "recent" => "Recent Pastes"
    })

    Hibana.Plugins.I18n.put_translations("vi", %{
      "create_paste" => "Tao Paste",
      "view_paste" => "Xem Paste",
      "not_found" => "Khong tim thay",
      "expires_in" => "Het han sau",
      "never" => "Khong het han",
      "views" => "Luot xem",
      "raw" => "Van ban goc",
      "copy" => "Sao chep",
      "recent" => "Paste Gan Day"
    })

    seed_data()

    children = [
      Pastebin.Endpoint,
      Pastebin.Cleaner
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pastebin.Supervisor)
  end

  defp seed_data do
    Pastebin.Store.create(%{
      content: "IO.puts(\"Hello from Elixir!\")\nEnum.map(1..10, &(&1 * 2))",
      title: "Hello Elixir",
      language: "elixir"
    })

    Pastebin.Store.create(%{
      content: "print('Hello from Python!')\nfor i in range(10):\n    print(i * 2)",
      title: "Hello Python",
      language: "python"
    })

    Pastebin.Store.create(%{
      content: "console.log('Hello from JavaScript!');\n[1,2,3].map(x => x * 2);",
      title: "Hello JavaScript",
      language: "javascript"
    })
  end
end
