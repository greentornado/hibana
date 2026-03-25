defmodule LivePoll.PageController do
  use Hibana.Controller

  def index(conn) do
    polls =
      LivePoll.PollStore.list()
      |> Enum.map(fn poll ->
        counts = 0..(length(poll.options) - 1) |> Enum.map(fn i -> Map.get(poll.votes, i, 0) end)
        total = Enum.sum(counts)

        """
        <a href="/poll/#{poll.id}" class="poll-card">
          <h3>#{html_escape(poll.question)}</h3>
          <div class="poll-meta">#{total} votes &middot; #{length(poll.options)} options</div>
        </a>
        """
      end)
      |> Enum.join("\n")

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Live Poll - Hibana</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0f0f0f; color: #e0e0e0; min-height: 100vh;
        }
        .container { max-width: 720px; margin: 0 auto; padding: 40px 20px; }
        h1 { font-size: 2rem; margin-bottom: 8px; color: #fff; }
        .subtitle { color: #888; margin-bottom: 32px; }
        .section-title { font-size: 1.2rem; color: #aaa; margin: 32px 0 16px; border-bottom: 1px solid #222; padding-bottom: 8px; }

        /* Form */
        .form-card {
          background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 12px;
          padding: 24px; margin-bottom: 32px;
        }
        label { display: block; color: #aaa; font-size: 0.85rem; margin-bottom: 6px; margin-top: 16px; }
        label:first-child { margin-top: 0; }
        input[type="text"], select {
          width: 100%; padding: 10px 14px; background: #111; border: 1px solid #333;
          border-radius: 8px; color: #fff; font-size: 0.95rem; outline: none;
        }
        input[type="text"]:focus, select:focus { border-color: #6c5ce7; }
        .option-row { display: flex; gap: 8px; margin-bottom: 8px; }
        .option-row input { flex: 1; }
        .btn-remove {
          background: #ff4757; color: #fff; border: none; border-radius: 8px;
          width: 36px; cursor: pointer; font-size: 1.1rem;
        }
        .btn-add {
          background: transparent; color: #6c5ce7; border: 1px dashed #6c5ce7;
          border-radius: 8px; padding: 8px 16px; cursor: pointer; font-size: 0.9rem;
          margin-top: 4px;
        }
        .btn-add:hover { background: rgba(108,92,231,0.1); }
        .toggle-row { display: flex; align-items: center; gap: 10px; margin-top: 16px; }
        .toggle {
          appearance: none; width: 44px; height: 24px; background: #333; border-radius: 12px;
          position: relative; cursor: pointer; outline: none; border: none;
        }
        .toggle::after {
          content: ''; position: absolute; top: 2px; left: 2px; width: 20px; height: 20px;
          background: #888; border-radius: 50%; transition: all 0.2s;
        }
        .toggle:checked { background: #6c5ce7; }
        .toggle:checked::after { left: 22px; background: #fff; }
        .btn-submit {
          width: 100%; padding: 12px; background: #6c5ce7; color: #fff; border: none;
          border-radius: 8px; font-size: 1rem; cursor: pointer; margin-top: 20px;
          font-weight: 600;
        }
        .btn-submit:hover { background: #5a4bd1; }
        .btn-submit:disabled { background: #444; cursor: not-allowed; }

        /* Poll list */
        .poll-card {
          display: block; background: #1a1a1a; border: 1px solid #2a2a2a;
          border-radius: 12px; padding: 20px; margin-bottom: 12px;
          text-decoration: none; color: inherit; transition: border-color 0.2s;
        }
        .poll-card:hover { border-color: #6c5ce7; }
        .poll-card h3 { color: #fff; margin-bottom: 6px; }
        .poll-meta { color: #666; font-size: 0.85rem; }
        .empty { color: #555; text-align: center; padding: 40px; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Live Poll</h1>
        <p class="subtitle">Create polls and see votes update in real-time</p>

        <div class="form-card">
          <label for="question">Question</label>
          <input type="text" id="question" placeholder="What do you want to ask?">

          <label>Options</label>
          <div id="options-list">
            <div class="option-row">
              <input type="text" class="option-input" placeholder="Option 1">
              <button class="btn-remove" onclick="removeOption(this)" title="Remove">&times;</button>
            </div>
            <div class="option-row">
              <input type="text" class="option-input" placeholder="Option 2">
              <button class="btn-remove" onclick="removeOption(this)" title="Remove">&times;</button>
            </div>
          </div>
          <button class="btn-add" onclick="addOption()">+ Add option</button>

          <div class="toggle-row">
            <input type="checkbox" id="multiple" class="toggle">
            <label for="multiple" style="margin:0;cursor:pointer;">Allow multiple votes per person</label>
          </div>

          <label for="expires">Expiry</label>
          <select id="expires">
            <option value="">No expiry</option>
            <option value="900">15 minutes</option>
            <option value="3600">1 hour</option>
            <option value="86400">1 day</option>
            <option value="604800">1 week</option>
          </select>

          <button class="btn-submit" id="create-btn" onclick="createPoll()">Create Poll</button>
        </div>

        <div class="section-title">Recent Polls</div>
        <div id="polls-list">
          #{if polls == "", do: "<div class='empty'>No polls yet. Create one above!</div>", else: polls}
        </div>
      </div>

      <script>
        let optionCount = 2;

        function addOption() {
          optionCount++;
          const row = document.createElement('div');
          row.className = 'option-row';
          const input = document.createElement('input');
          input.type = 'text';
          input.className = 'option-input';
          input.placeholder = 'Option ' + optionCount;
          const btn = document.createElement('button');
          btn.className = 'btn-remove';
          btn.title = 'Remove';
          btn.textContent = String.fromCharCode(215);
          btn.onclick = function() { removeOption(btn); };
          row.appendChild(input);
          row.appendChild(btn);
          document.getElementById('options-list').appendChild(row);
        }

        function removeOption(btn) {
          const list = document.getElementById('options-list');
          if (list.children.length > 2) {
            btn.parentElement.remove();
          }
        }

        async function createPoll() {
          const question = document.getElementById('question').value.trim();
          const optionEls = document.querySelectorAll('.option-input');
          const options = Array.from(optionEls).map(function(el) { return el.value.trim(); }).filter(function(v) { return v; });
          const multiple = document.getElementById('multiple').checked;
          const expiresVal = document.getElementById('expires').value;

          if (!question) { alert('Please enter a question'); return; }
          if (options.length < 2) { alert('At least 2 options are required'); return; }

          const body = { question: question, options: options, multiple: multiple };
          if (expiresVal) body.expires_in = parseInt(expiresVal);

          const btn = document.getElementById('create-btn');
          btn.disabled = true;
          btn.textContent = 'Creating...';

          try {
            const res = await fetch('/api/polls', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(body)
            });
            const data = await res.json();
            if (data.poll) {
              window.location.href = '/poll/' + data.poll.id;
            } else {
              alert(data.error || 'Failed to create poll');
            }
          } catch (e) {
            alert('Network error');
          } finally {
            btn.disabled = false;
            btn.textContent = 'Create Poll';
          }
        }
      </script>
    </body>
    </html>
    """)
  end

  def show(conn) do
    id = conn.params["id"]

    case LivePoll.PollStore.get(id) do
      {:error, :not_found} ->
        put_status(conn, 404) |> html(not_found_html())

      {:ok, poll} ->
        counts = 0..(length(poll.options) - 1) |> Enum.map(fn i -> Map.get(poll.votes, i, 0) end)
        total = Enum.sum(counts)

        options_json = Jason.encode!(poll.options)
        counts_json = Jason.encode!(counts)

        option_buttons =
          poll.options
          |> Enum.with_index()
          |> Enum.map(fn {opt, i} ->
            pct = if total > 0, do: Float.round(Enum.at(counts, i) / total * 100, 1), else: 0

            """
            <button class="option-btn" data-index="#{i}" onclick="castVote(#{i})">
              <div class="option-label">
                <span class="option-text">#{html_escape(opt)}</span>
                <span class="option-stats">
                  <span class="option-count" id="count-#{i}">#{Enum.at(counts, i)}</span>
                  <span class="option-pct" id="pct-#{i}">#{pct}%</span>
                </span>
              </div>
              <div class="bar-bg">
                <div class="bar-fill" id="bar-#{i}" style="width: #{pct}%"></div>
              </div>
            </button>
            """
          end)
          |> Enum.join("\n")

        html(conn, """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>#{html_escape(poll.question)} - Live Poll</title>
          <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: #0f0f0f; color: #e0e0e0; min-height: 100vh;
            }
            .container { max-width: 640px; margin: 0 auto; padding: 40px 20px; }
            .back { color: #6c5ce7; text-decoration: none; font-size: 0.9rem; }
            .back:hover { text-decoration: underline; }
            h1 { font-size: 1.8rem; color: #fff; margin: 16px 0 8px; }
            .poll-info { color: #666; font-size: 0.85rem; margin-bottom: 24px; }
            .total-votes {
              text-align: center; font-size: 1.1rem; color: #888; margin-bottom: 24px;
            }
            .total-votes span { color: #6c5ce7; font-weight: 700; font-size: 1.4rem; }

            .option-btn {
              display: block; width: 100%; background: #1a1a1a; border: 1px solid #2a2a2a;
              border-radius: 12px; padding: 16px 20px; margin-bottom: 12px;
              cursor: pointer; text-align: left; color: inherit; transition: all 0.2s;
            }
            .option-btn:hover { border-color: #6c5ce7; background: #1e1e2e; }
            .option-btn.voted { border-color: #6c5ce7; cursor: default; }
            .option-btn.disabled { cursor: not-allowed; opacity: 0.7; }
            .option-label {
              display: flex; justify-content: space-between; align-items: center;
              margin-bottom: 10px;
            }
            .option-text { font-size: 1rem; font-weight: 500; color: #fff; }
            .option-stats { display: flex; gap: 12px; align-items: baseline; }
            .option-count { color: #888; font-size: 0.85rem; }
            .option-pct { color: #6c5ce7; font-weight: 700; font-size: 1.1rem; min-width: 50px; text-align: right; }

            .bar-bg {
              width: 100%; height: 6px; background: #222; border-radius: 3px; overflow: hidden;
            }
            .bar-fill {
              height: 100%; background: linear-gradient(90deg, #6c5ce7, #a29bfe);
              border-radius: 3px; transition: width 0.5s ease;
            }

            .status-bar {
              display: flex; justify-content: space-between; align-items: center;
              margin-top: 24px; padding: 12px 16px; background: #1a1a1a;
              border-radius: 8px; font-size: 0.85rem;
            }
            .live-dot {
              width: 8px; height: 8px; background: #00b894; border-radius: 50%;
              display: inline-block; margin-right: 6px; animation: pulse 2s infinite;
            }
            @keyframes pulse {
              0%, 100% { opacity: 1; }
              50% { opacity: 0.4; }
            }
            .share-link {
              color: #6c5ce7; cursor: pointer; text-decoration: none;
            }
            .share-link:hover { text-decoration: underline; }
            .expired-banner {
              background: #ff4757; color: #fff; text-align: center; padding: 10px;
              border-radius: 8px; margin-bottom: 16px; font-weight: 600;
            }
            .toast {
              position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
              background: #333; color: #fff; padding: 10px 20px; border-radius: 8px;
              font-size: 0.9rem; opacity: 0; transition: opacity 0.3s;
              pointer-events: none;
            }
            .toast.show { opacity: 1; }
          </style>
        </head>
        <body>
          <div class="container">
            <a href="/" class="back">&larr; Back to polls</a>
            <h1>#{html_escape(poll.question)}</h1>
            <div class="poll-info">
              #{if poll.multiple, do: "Multiple votes allowed", else: "One vote per person"}
              #{if poll.expires_at, do: " &middot; Expires in #{time_remaining(poll.expires_at)}", else: ""}
            </div>

            #{if LivePoll.PollStore.expired?(poll), do: "<div class='expired-banner'>This poll has ended</div>", else: ""}

            <div class="total-votes">
              <span id="total-count">#{total}</span> total votes
            </div>

            <div id="options">
              #{option_buttons}
            </div>

            <div class="status-bar">
              <div><span class="live-dot" id="live-dot"></span><span id="status-text">Connecting...</span></div>
              <span class="share-link" onclick="copyLink()">Copy link</span>
            </div>
          </div>

          <div class="toast" id="toast"></div>

          <script>
            var pollId = "#{id}";
            var options = #{options_json};
            var isMultiple = #{if poll.multiple, do: "true", else: "false"};
            var counts = #{counts_json};
            var total = #{total};
            var hasVoted = localStorage.getItem('voted_' + pollId) === 'true';
            var evtSource = null;

            function updateUI() {
              total = counts.reduce(function(a, b) { return a + b; }, 0);
              document.getElementById('total-count').textContent = total;
              for (var i = 0; i < counts.length; i++) {
                var pct = total > 0 ? (counts[i] / total * 100).toFixed(1) : '0.0';
                document.getElementById('count-' + i).textContent = counts[i];
                document.getElementById('pct-' + i).textContent = pct + '%';
                document.getElementById('bar-' + i).style.width = pct + '%';
              }
            }

            function disableVoting() {
              var btns = document.querySelectorAll('.option-btn');
              for (var i = 0; i < btns.length; i++) {
                btns[i].classList.add('disabled');
                btns[i].onclick = null;
              }
            }

            async function castVote(optionIndex) {
              if (hasVoted && !isMultiple) return;

              try {
                var res = await fetch('/api/polls/' + pollId + '/vote', {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ option: optionIndex })
                });
                var data = await res.json();

                if (data.success) {
                  counts = data.counts;
                  total = data.total;
                  updateUI();

                  var clickedBtn = document.querySelector('[data-index="' + optionIndex + '"]');
                  clickedBtn.classList.add('voted');

                  if (!isMultiple) {
                    hasVoted = true;
                    localStorage.setItem('voted_' + pollId, 'true');
                    disableVoting();
                  }
                  showToast('Vote recorded!');
                } else {
                  showToast(data.error || 'Failed to vote');
                }
              } catch (e) {
                showToast('Network error');
              }
            }

            function connectSSE() {
              evtSource = new EventSource('/api/polls/' + pollId + '/stream');

              evtSource.addEventListener('init', function(e) {
                var data = JSON.parse(e.data);
                counts = data.counts;
                total = data.total;
                updateUI();
              });

              evtSource.addEventListener('vote', function(e) {
                var data = JSON.parse(e.data);
                counts = data.counts;
                total = data.total;
                updateUI();
              });

              evtSource.addEventListener('poll_closed', function(e) {
                var data = JSON.parse(e.data);
                counts = data.counts;
                updateUI();
                disableVoting();
                showToast('Poll closed! Winner: ' + data.winner);
              });

              evtSource.onopen = function() {
                document.getElementById('live-dot').style.background = '#00b894';
                document.getElementById('status-text').textContent = 'Live';
              };

              evtSource.onerror = function() {
                document.getElementById('live-dot').style.background = '#ff4757';
                document.getElementById('status-text').textContent = 'Reconnecting...';
              };
            }

            function copyLink() {
              navigator.clipboard.writeText(window.location.href).then(function() { showToast('Link copied!'); });
            }

            function showToast(msg) {
              var t = document.getElementById('toast');
              t.textContent = msg;
              t.classList.add('show');
              setTimeout(function() { t.classList.remove('show'); }, 2000);
            }

            if (hasVoted && !isMultiple) {
              disableVoting();
            }

            connectSSE();
          </script>
        </body>
        </html>
        """)
    end
  end

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp time_remaining(expires_at) do
    diff = expires_at - System.system_time(:second)

    cond do
      diff <= 0 -> "Expired"
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h"
      true -> "#{div(diff, 86400)}d"
    end
  end

  defp not_found_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Poll Not Found</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          background: #0f0f0f; color: #e0e0e0; display: flex; justify-content: center;
          align-items: center; min-height: 100vh; text-align: center;
        }
        a { color: #6c5ce7; }
      </style>
    </head>
    <body>
      <div>
        <h1>Poll not found</h1>
        <p><a href="/">Back to polls</a></p>
      </div>
    </body>
    </html>
    """
  end
end
