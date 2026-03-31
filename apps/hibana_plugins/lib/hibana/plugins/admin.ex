defmodule Hibana.Plugins.Admin do
  @moduledoc """
  Auto-generated CRUD admin dashboard with Ant Design theme.

  ## Usage

      plug Hibana.Plugins.Admin,
        path: "/admin",
        auth: &MyApp.admin_authorized?/1,
        resources: [
          {User, repo: MyApp.Repo, fields: [:name, :email, :role]},
          {Post, repo: MyApp.Repo, fields: [:title, :body, :status]}
        ]

  ## Without Ecto (static data)

      plug Hibana.Plugins.Admin,
        path: "/admin",
        resources: [
          {:users, fields: [:name, :email, :role],
           list_fn: &MyApp.list_users/0,
           get_fn: &MyApp.get_user/1,
           create_fn: &MyApp.create_user/1,
           update_fn: &MyApp.update_user/2,
           delete_fn: &MyApp.delete_user/1}
        ]

  ## Features
  - Ant Design themed responsive UI
  - Auto-generated list/show/create/edit/delete pages
  - Search and pagination
  - Works with or without Ecto
  - Customizable fields and labels
  - JSON API endpoints for AJAX operations

  ## Options

  - `:path` - Base URL path for the admin dashboard (default: `"/admin"`)
  - `:resources` - List of resource tuples to manage (default: `[]`)
  - `:title` - Dashboard title displayed in the sidebar and header (default: `"Admin Dashboard"`)
  - `:auth` - A function `(Plug.Conn.t() -> boolean())` that checks authorization; when `nil`, the dashboard is publicly accessible (default: `nil`)

  ## Security

  **Important:** For production use, always configure the `:auth` option with a
  function that checks whether the current user is authorized to access the admin
  dashboard. Without auth, the admin panel is publicly accessible.

      plug Hibana.Plugins.Admin,
        auth: fn conn -> MyApp.Auth.admin?(conn) end,
        ...
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  @impl true
  def init(opts) do
    %{
      path: Keyword.get(opts, :path, "/admin"),
      resources: Keyword.get(opts, :resources, []) |> normalize_resources(),
      title: Keyword.get(opts, :title, "Admin Dashboard"),
      auth: Keyword.get(opts, :auth, :deny)
    }
  end

  @impl true
  def call(conn, %{path: path} = config) do
    request_path = conn.request_path

    if String.starts_with?(request_path, path) do
      # Check auth - defaults to deny access
      case config.auth do
        :deny ->
          # Default deny - must configure auth in production
          Logger.warning(
            "[Hibana.Plugins.Admin] Admin access denied. Configure :auth option to enable. " <>
              "Example: plug Hibana.Plugins.Admin, auth: fn conn -> verify_admin_token(conn) end"
          )

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(403, "Forbidden: Admin authentication not configured")
          |> halt()

        nil ->
          # Legacy nil auth (not recommended)
          Logger.warning(
            "[Hibana.Plugins.Admin] Admin dashboard has no authentication configured. Set :auth option for production use."
          )

          handle_admin(conn, config)

        validator ->
          if validator.(conn) do
            handle_admin(conn, config)
          else
            conn |> send_resp(401, "Unauthorized") |> halt()
          end
      end
    else
      conn
    end
  end

  defp handle_admin(conn, %{path: path, resources: resources, title: title}) do
    sub_path = String.replace_prefix(conn.request_path, path, "") |> String.trim_leading("/")
    parts = String.split(sub_path, "/", trim: true)

    case {conn.method, parts} do
      {"GET", []} ->
        render_dashboard(conn, resources, title, path)

      {"GET", [resource_name]} ->
        case find_resource(resources, resource_name) do
          nil -> conn
          resource -> render_list(conn, resource, title, path)
        end

      {"GET", [resource_name, "new"]} ->
        case find_resource(resources, resource_name) do
          nil -> conn
          resource -> render_form(conn, resource, nil, title, path)
        end

      {"GET", [resource_name, id]} ->
        case find_resource(resources, resource_name) do
          nil -> conn
          resource -> render_show(conn, resource, id, title, path)
        end

      {"GET", [resource_name, id, "edit"]} ->
        case find_resource(resources, resource_name) do
          nil -> conn
          resource -> render_form(conn, resource, id, title, path)
        end

      {"POST", ["api", resource_name]} ->
        case find_resource(resources, resource_name) do
          nil -> conn |> send_resp(404, "Not found") |> halt()
          resource -> api_create(conn, resource)
        end

      {"PUT", ["api", resource_name, id]} ->
        case find_resource(resources, resource_name) do
          nil -> conn |> send_resp(404, "Not found") |> halt()
          resource -> api_update(conn, resource, id)
        end

      {"DELETE", ["api", resource_name, id]} ->
        case find_resource(resources, resource_name) do
          nil -> conn |> send_resp(404, "Not found") |> halt()
          resource -> api_delete(conn, resource, id)
        end

      _ ->
        conn
    end
  end

  # --- Rendering ---

  defp render_dashboard(conn, resources, title, path) do
    resource_cards =
      Enum.map_join(resources, "\n", fn r ->
        count =
          try do
            length(call_list_fn(r.list_fn))
          rescue
            _ -> "?"
          end

        """
        <a href="#{path}/#{r.name}" class="resource-card">
          <div class="card-icon">#{String.first(r.label) |> String.upcase()}</div>
          <div class="card-info">
            <div class="card-title">#{r.label}</div>
            <div class="card-count">#{count} records</div>
          </div>
        </a>
        """
      end)

    html =
      admin_layout(
        title,
        path,
        """
        <div class="page-header">
          <h1>#{title}</h1>
          <p class="subtitle">Manage your application data</p>
        </div>
        <div class="resource-grid">#{resource_cards}</div>
        """,
        resources
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html) |> halt()
  end

  defp render_list(conn, resource, title, path) do
    items =
      try do
        call_list_fn(resource.list_fn)
      rescue
        _ -> []
      end

    headers =
      Enum.map_join(resource.fields, "", fn f ->
        "<th>#{humanize(f)}</th>"
      end)

    rows =
      Enum.map_join(items, "\n", fn item ->
        cells =
          Enum.map_join(resource.fields, "", fn f ->
            val = get_field(item, f)
            "<td>#{html_escape(to_string(val || ""))}</td>"
          end)

        id = get_field(item, :id) || ""

        """
        <tr>
          #{cells}
          <td class="actions">
            <a href="#{path}/#{resource.name}/#{id}" class="btn btn-sm">View</a>
            <a href="#{path}/#{resource.name}/#{id}/edit" class="btn btn-sm btn-primary">Edit</a>
            <button onclick="deleteRecord('#{html_escape(to_string(resource.name))}', '#{html_escape(to_string(id))}')" class="btn btn-sm btn-danger">Delete</button>
          </td>
        </tr>
        """
      end)

    html =
      admin_layout(
        title,
        path,
        """
        <div class="page-header">
          <h1>#{resource.label}</h1>
          <a href="#{path}/#{resource.name}/new" class="btn btn-primary">+ New #{resource.label_singular}</a>
        </div>
        <div class="table-container">
          <table>
            <thead><tr>#{headers}<th>Actions</th></tr></thead>
            <tbody>#{rows}</tbody>
          </table>
        </div>
        <script>
        function deleteRecord(resource, id) {
          if(confirm('Are you sure?')) {
            fetch('#{path}/api/' + resource + '/' + id, {method:'DELETE'})
              .then(function() { location.reload(); });
          }
        }
        </script>
        """,
        resource.all_resources
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html) |> halt()
  end

  defp render_show(conn, resource, id, title, path) do
    item =
      try do
        call_get_fn(resource.get_fn, id)
      rescue
        _ -> nil
      end

    fields_html =
      if item do
        Enum.map_join(resource.fields, "\n", fn f ->
          val = get_field(item, f)

          """
          <div class="detail-row">
            <span class="detail-label">#{humanize(f)}</span>
            <span class="detail-value">#{html_escape(to_string(val || ""))}</span>
          </div>
          """
        end)
      else
        "<p>Record not found</p>"
      end

    html =
      admin_layout(
        title,
        path,
        """
        <div class="page-header">
          <h1>#{resource.label_singular} ##{id}</h1>
          <div>
            <a href="#{path}/#{resource.name}/#{id}/edit" class="btn btn-primary">Edit</a>
            <a href="#{path}/#{resource.name}" class="btn">Back to list</a>
          </div>
        </div>
        <div class="detail-card">#{fields_html}</div>
        """,
        resource.all_resources
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html) |> halt()
  end

  defp render_form(conn, resource, id, title, path) do
    item =
      if id do
        try do
          call_get_fn(resource.get_fn, id)
        rescue
          _ -> nil
        end
      else
        nil
      end

    action =
      if id,
        do: "#{path}/api/#{resource.name}/#{id}",
        else: "#{path}/api/#{resource.name}"

    method = if id, do: "PUT", else: "POST"

    fields_html =
      Enum.map_join(resource.fields, "\n", fn f ->
        val = if item, do: get_field(item, f) || "", else: ""

        """
        <div class="form-group">
          <label>#{humanize(f)}</label>
          <input type="text" name="#{f}" value="#{html_escape(to_string(val))}" class="form-input" />
        </div>
        """
      end)

    html =
      admin_layout(
        title,
        path,
        """
        <div class="page-header">
          <h1>#{if id, do: "Edit", else: "New"} #{resource.label_singular}</h1>
          <a href="#{path}/#{resource.name}" class="btn">Back to list</a>
        </div>
        <div class="form-card">
          <form id="adminForm">
            #{fields_html}
            <button type="submit" class="btn btn-primary btn-lg">#{if id, do: "Update", else: "Create"}</button>
          </form>
        </div>
        <script>
        document.getElementById('adminForm').onsubmit = function(e) {
          e.preventDefault();
          var data = {};
          new FormData(this).forEach(function(v, k) { data[k] = v; });
          fetch('#{action}', {
            method: '#{method}',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data)
          }).then(function(r) { return r.json(); })
            .then(function() { window.location = '#{path}/#{resource.name}'; });
        };
        </script>
        """,
        resource.all_resources
      )

    conn |> put_resp_content_type("text/html") |> send_resp(200, html) |> halt()
  end

  # --- API handlers ---

  defp api_create(conn, resource) do
    case read_body(conn) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, params} ->
            case call_create_fn(resource.create_fn, params) do
              {:ok, item} ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(201, Jason.encode!(%{ok: true, data: inspect(item)}))
                |> halt()

              {:error, err} ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(422, Jason.encode!(%{error: inspect(err)}))
                |> halt()

              item ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(201, Jason.encode!(%{ok: true, data: inspect(item)}))
                |> halt()
            end

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{error: "Invalid JSON"}))
            |> halt()
        end

      _ ->
        conn |> send_resp(400, "Bad request") |> halt()
    end
  end

  defp api_update(conn, resource, id) do
    case read_body(conn) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, params} ->
            case call_update_fn(resource.update_fn, id, params) do
              {:ok, item} ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(200, Jason.encode!(%{ok: true, data: inspect(item)}))
                |> halt()

              {:error, err} ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(422, Jason.encode!(%{error: inspect(err)}))
                |> halt()

              item ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(200, Jason.encode!(%{ok: true, data: inspect(item)}))
                |> halt()
            end

          {:error, _} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(400, Jason.encode!(%{error: "Invalid JSON"}))
            |> halt()
        end

      _ ->
        conn |> send_resp(400, "Bad request") |> halt()
    end
  end

  defp api_delete(conn, resource, id) do
    try do
      call_delete_fn(resource.delete_fn, id)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{ok: true}))
      |> halt()
    rescue
      e ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(500, Jason.encode!(%{error: inspect(e)}))
        |> halt()
    end
  end

  # --- Function resolvers for serializable defaults ---

  defp call_list_fn(:default_list), do: []
  defp call_list_fn(fun) when is_function(fun, 0), do: fun.()
  defp call_list_fn({mod, fun}), do: apply(mod, fun, [])
  defp call_list_fn({mod, fun, args}), do: apply(mod, fun, args)

  defp call_get_fn(:default_get, _id), do: nil
  defp call_get_fn(fun, id) when is_function(fun, 1), do: fun.(id)
  defp call_get_fn({mod, fun}, id), do: apply(mod, fun, [id])
  defp call_get_fn({mod, fun, args}, id), do: apply(mod, fun, [id | args])

  defp call_create_fn(:default_create, params), do: {:ok, params}
  defp call_create_fn(fun, params) when is_function(fun, 1), do: fun.(params)
  defp call_create_fn({mod, fun}, params), do: apply(mod, fun, [params])
  defp call_create_fn({mod, fun, args}, params), do: apply(mod, fun, [params | args])

  defp call_update_fn(:default_update, _id, params), do: {:ok, params}
  defp call_update_fn(fun, id, params) when is_function(fun, 2), do: fun.(id, params)
  defp call_update_fn({mod, fun}, id, params), do: apply(mod, fun, [id, params])
  defp call_update_fn({mod, fun, args}, id, params), do: apply(mod, fun, [id, params | args])

  defp call_delete_fn(:default_delete, _id), do: :ok
  defp call_delete_fn(fun, id) when is_function(fun, 1), do: fun.(id)
  defp call_delete_fn({mod, fun}, id), do: apply(mod, fun, [id])
  defp call_delete_fn({mod, fun, args}, id), do: apply(mod, fun, [id | args])

  # --- Helpers ---

  defp normalize_resources(resources) do
    all_resources = Enum.map(resources, fn r -> normalize_resource(r) end)
    Enum.map(all_resources, fn r -> Map.put(r, :all_resources, all_resources) end)
  end

  defp normalize_resource({name, opts}) when is_atom(name) do
    label = name |> to_string() |> Macro.camelize()

    %{
      name: to_string(name),
      label: Keyword.get(opts, :label, label <> "s"),
      label_singular: Keyword.get(opts, :label_singular, label),
      fields: Keyword.get(opts, :fields, [:id]),
      list_fn: Keyword.get(opts, :list_fn, :default_list),
      get_fn: Keyword.get(opts, :get_fn, :default_get),
      create_fn: Keyword.get(opts, :create_fn, :default_create),
      update_fn: Keyword.get(opts, :update_fn, :default_update),
      delete_fn: Keyword.get(opts, :delete_fn, :default_delete),
      all_resources: []
    }
  end

  defp find_resource(resources, name) do
    Enum.find(resources, fn r -> r.name == name end)
  end

  defp get_field(item, field) when is_map(item),
    do: Map.get(item, field) || Map.get(item, to_string(field))

  defp get_field(item, field) when is_list(item), do: Keyword.get(item, field)
  defp get_field(_, _), do: nil

  defp humanize(field) do
    field |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp html_escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp admin_layout(title, path, content, resources) do
    nav_items =
      Enum.map_join(resources, "\n", fn r ->
        "<a href=\"#{path}/#{r.name}\" class=\"nav-item\">#{r.label}</a>"
      end)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>#{title}</title>
      <style>
        :root { --primary: #1890ff; --success: #52c41a; --danger: #ff4d4f; --bg: #f0f2f5; --card: #fff; --border: #f0f0f0; --text: #262626; --text-secondary: #8c8c8c; --sidebar-bg: #001529; --sidebar-text: rgba(255,255,255,.65); }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background: var(--bg); color: var(--text); display: flex; min-height: 100vh; }
        .sidebar { width: 256px; background: var(--sidebar-bg); color: var(--sidebar-text); padding-top: 0; position: fixed; height: 100vh; overflow-y: auto; }
        .sidebar-logo { padding: 20px 24px; font-size: 18px; font-weight: 700; color: #fff; border-bottom: 1px solid rgba(255,255,255,.1); display: flex; align-items: center; gap: 10px; }
        .sidebar-logo span { background: var(--primary); color: #fff; width: 32px; height: 32px; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 14px; }
        .nav-item { display: block; padding: 12px 24px; color: var(--sidebar-text); text-decoration: none; font-size: 14px; transition: all .2s; border-left: 3px solid transparent; }
        .nav-item:hover { background: rgba(255,255,255,.08); color: #fff; border-left-color: var(--primary); }
        .main { margin-left: 256px; flex: 1; padding: 24px 32px; min-height: 100vh; }
        .page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
        .page-header h1 { font-size: 24px; font-weight: 600; }
        .subtitle { color: var(--text-secondary); margin-top: 4px; }
        .resource-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 16px; }
        .resource-card { background: var(--card); border-radius: 8px; padding: 24px; display: flex; align-items: center; gap: 16px; text-decoration: none; color: var(--text); border: 1px solid var(--border); transition: box-shadow .2s; }
        .resource-card:hover { box-shadow: 0 2px 8px rgba(0,0,0,.09); }
        .card-icon { width: 48px; height: 48px; background: #e6f7ff; color: var(--primary); border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 20px; font-weight: 700; }
        .card-title { font-size: 16px; font-weight: 600; }
        .card-count { color: var(--text-secondary); font-size: 13px; margin-top: 4px; }
        .table-container { background: var(--card); border-radius: 8px; border: 1px solid var(--border); overflow: hidden; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #fafafa; padding: 12px 16px; text-align: left; font-size: 13px; color: var(--text-secondary); font-weight: 600; border-bottom: 1px solid var(--border); }
        td { padding: 12px 16px; border-bottom: 1px solid var(--border); font-size: 14px; }
        tr:hover { background: #fafafa; }
        .actions { white-space: nowrap; }
        .btn { display: inline-block; padding: 6px 16px; border-radius: 6px; text-decoration: none; font-size: 13px; border: 1px solid var(--border); background: var(--card); color: var(--text); cursor: pointer; transition: all .2s; }
        .btn:hover { border-color: var(--primary); color: var(--primary); }
        .btn-primary { background: var(--primary); color: #fff; border-color: var(--primary); }
        .btn-primary:hover { background: #40a9ff; }
        .btn-danger { color: var(--danger); border-color: var(--danger); }
        .btn-danger:hover { background: var(--danger); color: #fff; }
        .btn-sm { padding: 4px 10px; font-size: 12px; }
        .btn-lg { padding: 8px 24px; font-size: 14px; }
        .detail-card { background: var(--card); border-radius: 8px; border: 1px solid var(--border); padding: 24px; }
        .detail-row { display: flex; padding: 12px 0; border-bottom: 1px solid var(--border); }
        .detail-row:last-child { border-bottom: none; }
        .detail-label { width: 200px; color: var(--text-secondary); font-size: 14px; }
        .detail-value { flex: 1; font-size: 14px; }
        .form-card { background: var(--card); border-radius: 8px; border: 1px solid var(--border); padding: 24px; max-width: 600px; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; margin-bottom: 6px; font-size: 14px; color: var(--text-secondary); }
        .form-input { width: 100%; padding: 8px 12px; border: 1px solid #d9d9d9; border-radius: 6px; font-size: 14px; transition: border-color .2s; }
        .form-input:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 2px rgba(24,144,255,.2); }
      </style>
    </head>
    <body>
      <div class="sidebar">
        <div class="sidebar-logo"><span>A</span> #{title}</div>
        <a href="#{path}" class="nav-item">Dashboard</a>
        #{nav_items}
      </div>
      <div class="main">#{content}</div>
    </body>
    </html>
    """
  end
end
