defmodule BackgroundJobs.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Background Jobs Demo</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px; }
        .card { border: 1px solid #ddd; padding: 20px; margin: 20px 0; border-radius: 8px; }
        button { padding: 10px 20px; font-size: 16px; cursor: pointer; background: #0066cc; color: white; border: none; border-radius: 4px; }
        button:hover { background: #0055aa; }
        button.danger { background: #cc0000; }
        button.danger:hover { background: #aa0000; }
        pre { background: #f4f4f4; padding: 15px; overflow-x: auto; border-radius: 4px; }
        input, select { padding: 10px; font-size: 16px; margin: 5px 0; width: 100%; box-sizing: border-box; }
        label { font-weight: bold; margin-top: 10px; display: block; }
      </style>
    </head>
    <body>
      <h1>Background Jobs Demo</h1>
      
      <div class="card">
        <h2>Send Email Job</h2>
        <form id="email-form">
          <label>To:</label>
          <input type="email" name="to" value="user@example.com" required />
          <label>Subject:</label>
          <input type="text" name="subject" value="Test Email" required />
          <label>Body:</label>
          <textarea name="body" rows="3" required>Hello from Background Jobs!</textarea>
          <button type="submit">Send Email</button>
        </form>
        <p id="email-result"></p>
      </div>

      <div class="card">
        <h2>Welcome Email (with delay)</h2>
        <form id="welcome-form">
          <label>User Email:</label>
          <input type="email" name="email" value="newuser@example.com" required />
          <label>Delay (seconds):</label>
          <input type="number" name="delay" value="5" min="0" />
          <button type="submit">Schedule Welcome Email</button>
        </form>
        <p id="welcome-result"></p>
      </div>

      <div class="card">
        <h2>Queue Statistics</h2>
        <button onclick="loadStats()">Refresh Stats</button>
        <pre id="stats">Click refresh to load stats</pre>
      </div>

      <div class="card">
        <h2>Clear Queue</h2>
        <button class="danger" onclick="clearQueue()">Clear All Jobs</button>
        <p id="clear-result"></p>
      </div>

      <script>
        async function postForm(url, formId, resultId) {
          const form = document.getElementById(formId);
          const formData = new FormData(form);
          const data = Object.fromEntries(formData);
          
          try {
            const response = await fetch(url, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(data)
            });
            const result = await response.json();
            document.getElementById(resultId).textContent = JSON.stringify(result, null, 2);
          } catch (error) {
            document.getElementById(resultId).textContent = 'Error: ' + error.message;
          }
        }

        document.getElementById('email-form').onsubmit = (e) => {
          e.preventDefault();
          postForm('/jobs/send-email', 'email-form', 'email-result');
        };

        document.getElementById('welcome-form').onsubmit = (e) => {
          e.preventDefault();
          postForm('/jobs/welcome-email', 'welcome-form', 'welcome-result');
        };

        async function loadStats() {
          try {
            const response = await fetch('/jobs/stats');
            const data = await response.json();
            document.getElementById('stats').textContent = JSON.stringify(data, null, 2);
          } catch (error) {
            document.getElementById('stats').textContent = 'Error: ' + error.message;
          }
        }

        async function clearQueue() {
          try {
            const response = await fetch('/jobs/clear', { method: 'POST' });
            const data = await response.json();
            document.getElementById('clear-result').textContent = JSON.stringify(data, null, 2);
            loadStats();
          } catch (error) {
            document.getElementById('clear-result').textContent = 'Error: ' + error.message;
          }
        }
      </script>
    </body>
    </html>
    """)
  end

  def send_email(conn) do
    %{to: to, subject: subject, body: body} = conn.body_params

    job_data = %{to: to, subject: subject, body: body}
    BackgroundJobs.SendEmailJob.enqueue(job_data)

    json(conn, %{message: "Email job enqueued", job: job_data})
  end

  def welcome_email(conn) do
    %{email: email, delay: delay} = conn.body_params
    delay_ms = (String.to_integer(delay) || 0) * 1000

    job_data = %{email: email}

    if delay_ms > 0 do
      BackgroundJobs.SendEmailJob.enqueue(job_data, delay: delay_ms)
      json(conn, %{message: "Welcome email scheduled", delay_seconds: delay, job: job_data})
    else
      BackgroundJobs.SendEmailJob.enqueue(job_data)
      json(conn, %{message: "Welcome email enqueued", job: job_data})
    end
  end

  def stats(conn) do
    stats = Hibana.Queue.stats()
    json(conn, stats)
  end

  def clear(conn) do
    Hibana.Queue.clear()
    json(conn, %{message: "Queue cleared"})
  end
end
