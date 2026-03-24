# `Hibana.Plugins.Admin`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/admin.ex#L1)

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

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
