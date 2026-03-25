defmodule TypingRace.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, lobby_html())
  end

  def race(conn) do
    code = conn.params["code"]
    html(conn, race_html(code))
  end

  defp lobby_html do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Typing Speed Race</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background: #1a1a2e;
          color: #e0e0e0;
          min-height: 100vh;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
        }
        .container {
          max-width: 500px;
          width: 90%;
          padding: 40px;
        }
        h1 {
          font-size: 2.5em;
          text-align: center;
          margin-bottom: 10px;
          background: linear-gradient(135deg, #e94560, #f5a623);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        .subtitle {
          text-align: center;
          color: #888;
          margin-bottom: 40px;
          font-size: 1.1em;
        }
        .checkered {
          height: 6px;
          background: repeating-linear-gradient(90deg, #e94560 0px, #e94560 12px, #1a1a2e 12px, #1a1a2e 24px);
          margin-bottom: 30px;
          border-radius: 3px;
        }
        .card {
          background: #16213e;
          border-radius: 12px;
          padding: 30px;
          margin-bottom: 20px;
          border: 1px solid #0f3460;
        }
        .card h2 {
          font-size: 1.3em;
          margin-bottom: 15px;
          color: #f5a623;
        }
        input {
          width: 100%;
          padding: 12px 16px;
          background: #1a1a2e;
          border: 1px solid #0f3460;
          border-radius: 8px;
          color: #e0e0e0;
          font-size: 1em;
          margin-bottom: 12px;
          outline: none;
          transition: border-color 0.2s;
        }
        input:focus { border-color: #e94560; }
        input::placeholder { color: #555; }
        .row { display: flex; gap: 10px; }
        .row input { flex: 1; }
        button {
          width: 100%;
          padding: 14px;
          background: linear-gradient(135deg, #e94560, #c81d4e);
          color: white;
          border: none;
          border-radius: 8px;
          font-size: 1.1em;
          font-weight: bold;
          cursor: pointer;
          transition: transform 0.1s, box-shadow 0.2s;
        }
        button:hover { transform: translateY(-1px); box-shadow: 0 4px 15px rgba(233, 69, 96, 0.4); }
        button:active { transform: translateY(0); }
        button.secondary {
          background: linear-gradient(135deg, #0f3460, #16213e);
          border: 1px solid #0f3460;
        }
        button.secondary:hover { box-shadow: 0 4px 15px rgba(15, 52, 96, 0.4); }
        .error { color: #e94560; font-size: 0.9em; margin-top: 8px; display: none; }
        .or-divider {
          text-align: center;
          color: #555;
          margin: 0;
          font-size: 0.9em;
        }
        select {
          width: 100%;
          padding: 12px 16px;
          background: #1a1a2e;
          border: 1px solid #0f3460;
          border-radius: 8px;
          color: #e0e0e0;
          font-size: 1em;
          margin-bottom: 12px;
          outline: none;
        }
        label { display: block; color: #888; font-size: 0.9em; margin-bottom: 6px; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Typing Speed Race</h1>
        <p class="subtitle">Compete with friends to type the fastest</p>
        <div class="checkered"></div>

        <div class="card">
          <h2>Create a Race</h2>
          <input type="text" id="hostName" placeholder="Your name" maxlength="20" />
          <label for="maxPlayers">Max players</label>
          <select id="maxPlayers">
            <option value="2">2 players</option>
            <option value="3">3 players</option>
            <option value="4" selected>4 players</option>
          </select>
          <button onclick="createRace()">Create Race</button>
          <p class="error" id="createError"></p>
        </div>

        <p class="or-divider">- or -</p>

        <div class="card">
          <h2>Join a Race</h2>
          <input type="text" id="joinName" placeholder="Your name" maxlength="20" />
          <div class="row">
            <input type="text" id="raceCode" placeholder="4-digit code" maxlength="4" pattern="[0-9]*" />
          </div>
          <button class="secondary" onclick="joinRace()">Join Race</button>
          <p class="error" id="joinError"></p>
        </div>
      </div>

      <script>
        function showError(id, msg) {
          var el = document.getElementById(id);
          el.textContent = msg;
          el.style.display = 'block';
          setTimeout(function() { el.style.display = 'none'; }, 4000);
        }

        async function createRace() {
          var name = document.getElementById('hostName').value.trim();
          if (!name) { showError('createError', 'Please enter your name'); return; }

          var maxPlayers = parseInt(document.getElementById('maxPlayers').value);

          try {
            var res = await fetch('/api/races', {
              method: 'POST',
              headers: {'Content-Type': 'application/json'},
              body: JSON.stringify({max_players: maxPlayers})
            });
            var data = await res.json();
            if (data.code) {
              var joinRes = await fetch('/api/races/' + data.code + '/join', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({name: name})
              });
              var joinData = await joinRes.json();
              if (joinData.ok) {
                window.location.href = '/race/' + data.code + '?name=' + encodeURIComponent(name) + '&host=1';
              } else {
                showError('createError', joinData.error || 'Failed to join');
              }
            } else {
              showError('createError', data.error || 'Failed to create race');
            }
          } catch (e) {
            showError('createError', 'Network error');
          }
        }

        async function joinRace() {
          var name = document.getElementById('joinName').value.trim();
          var code = document.getElementById('raceCode').value.trim();
          if (!name) { showError('joinError', 'Please enter your name'); return; }
          if (!code || code.length !== 4) { showError('joinError', 'Enter a 4-digit race code'); return; }

          try {
            var res = await fetch('/api/races/' + code + '/join', {
              method: 'POST',
              headers: {'Content-Type': 'application/json'},
              body: JSON.stringify({name: name})
            });
            var data = await res.json();
            if (data.ok) {
              window.location.href = '/race/' + code + '?name=' + encodeURIComponent(name);
            } else {
              showError('joinError', data.error || 'Failed to join race');
            }
          } catch (e) {
            showError('joinError', 'Network error');
          }
        }

        document.getElementById('raceCode').addEventListener('input', function(e) {
          this.value = this.value.replace(/[^0-9]/g, '');
        });
      </script>
    </body>
    </html>
    """
  end

  defp race_html(code) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Race #{code} - Typing Speed Race</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          background: #1a1a2e;
          color: #e0e0e0;
          min-height: 100vh;
          padding: 20px;
        }
        .header {
          display: flex;
          justify-content: space-between;
          align-items: center;
          max-width: 900px;
          margin: 0 auto 20px;
        }
        .header h1 {
          font-size: 1.5em;
          background: linear-gradient(135deg, #e94560, #f5a623);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
        }
        .race-code {
          background: #16213e;
          padding: 8px 20px;
          border-radius: 8px;
          font-size: 1.2em;
          font-weight: bold;
          color: #f5a623;
          border: 1px solid #0f3460;
          letter-spacing: 4px;
        }
        .checkered {
          height: 4px;
          background: repeating-linear-gradient(90deg, #e94560 0px, #e94560 10px, #1a1a2e 10px, #1a1a2e 20px);
          max-width: 900px;
          margin: 0 auto 20px;
          border-radius: 2px;
        }
        .main { max-width: 900px; margin: 0 auto; }

        #waiting { text-align: center; padding: 40px 0; }
        #waiting h2 { font-size: 1.8em; margin-bottom: 20px; color: #f5a623; }
        .player-list {
          display: flex;
          flex-wrap: wrap;
          gap: 12px;
          justify-content: center;
          margin: 30px 0;
        }
        .player-tag {
          background: #16213e;
          padding: 10px 20px;
          border-radius: 20px;
          border: 1px solid #0f3460;
          font-size: 1.1em;
        }
        .player-tag .dot {
          display: inline-block;
          width: 8px;
          height: 8px;
          background: #4ade80;
          border-radius: 50%;
          margin-right: 8px;
        }
        #startBtn {
          padding: 14px 40px;
          background: linear-gradient(135deg, #e94560, #c81d4e);
          color: white;
          border: none;
          border-radius: 8px;
          font-size: 1.1em;
          font-weight: bold;
          cursor: pointer;
          transition: transform 0.1s;
          display: none;
        }
        #startBtn:hover { transform: translateY(-1px); box-shadow: 0 4px 15px rgba(233, 69, 96, 0.4); }
        #startBtn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
        .share-hint { color: #888; margin-top: 20px; font-size: 0.95em; }

        #countdown { display: none; text-align: center; padding: 60px 0; }
        #countdown .number {
          font-size: 8em;
          font-weight: bold;
          background: linear-gradient(135deg, #e94560, #f5a623);
          -webkit-background-clip: text;
          -webkit-text-fill-color: transparent;
          animation: pulse 0.5s ease-in-out;
        }
        @keyframes pulse {
          0% { transform: scale(1.3); opacity: 0.5; }
          100% { transform: scale(1); opacity: 1; }
        }

        #racing { display: none; }
        .text-display {
          background: #16213e;
          border-radius: 12px;
          padding: 24px;
          font-size: 1.25em;
          line-height: 1.8;
          margin-bottom: 20px;
          border: 1px solid #0f3460;
          user-select: none;
        }
        .text-display .correct { color: #4ade80; }
        .text-display .err { color: #e94560; text-decoration: underline; }
        .text-display .current {
          background: rgba(233, 69, 96, 0.3);
          border-bottom: 2px solid #e94560;
        }
        .text-display .upcoming { color: #666; }
        #typeInput {
          width: 100%;
          padding: 16px;
          background: #16213e;
          border: 2px solid #0f3460;
          border-radius: 10px;
          color: #e0e0e0;
          font-size: 1.15em;
          outline: none;
          margin-bottom: 20px;
          transition: border-color 0.2s;
        }
        #typeInput:focus { border-color: #e94560; }
        .timer {
          text-align: center;
          font-size: 1.3em;
          color: #f5a623;
          margin-bottom: 20px;
          font-variant-numeric: tabular-nums;
        }
        .progress-section { margin-bottom: 20px; }
        .progress-bar-container {
          background: #16213e;
          border-radius: 10px;
          padding: 12px 16px;
          margin-bottom: 8px;
          border: 1px solid #0f3460;
        }
        .progress-info {
          display: flex;
          justify-content: space-between;
          margin-bottom: 6px;
          font-size: 0.95em;
        }
        .progress-name { font-weight: bold; }
        .progress-stats { color: #888; }
        .progress-track {
          height: 10px;
          background: #1a1a2e;
          border-radius: 5px;
          overflow: hidden;
        }
        .progress-fill {
          height: 100%;
          border-radius: 5px;
          transition: width 0.3s ease;
          min-width: 2px;
        }
        .color-0 { background: linear-gradient(90deg, #e94560, #f5a623); }
        .color-1 { background: linear-gradient(90deg, #4ade80, #22d3ee); }
        .color-2 { background: linear-gradient(90deg, #a78bfa, #f472b6); }
        .color-3 { background: linear-gradient(90deg, #fbbf24, #f97316); }

        #results { display: none; text-align: center; padding: 30px 0; }
        #results h2 { font-size: 2em; margin-bottom: 30px; color: #f5a623; }
        .podium {
          display: flex;
          justify-content: center;
          align-items: flex-end;
          gap: 16px;
          margin-bottom: 30px;
        }
        .podium-place {
          background: #16213e;
          border-radius: 12px;
          padding: 20px;
          text-align: center;
          border: 1px solid #0f3460;
          min-width: 140px;
        }
        .podium-place.first { border-color: #f5a623; order: 1; }
        .podium-place.second { order: 0; }
        .podium-place.third { order: 2; }
        .podium-position { font-size: 2em; font-weight: bold; margin-bottom: 8px; }
        .podium-place.first .podium-position { color: #f5a623; }
        .podium-place.second .podium-position { color: #c0c0c0; }
        .podium-place.third .podium-position { color: #cd7f32; }
        .podium-name { font-size: 1.2em; margin-bottom: 6px; }
        .podium-wpm { color: #888; }
        .podium-time { color: #666; font-size: 0.9em; }
        #raceAgainBtn {
          padding: 14px 40px;
          background: linear-gradient(135deg, #e94560, #c81d4e);
          color: white;
          border: none;
          border-radius: 8px;
          font-size: 1.1em;
          font-weight: bold;
          cursor: pointer;
          margin-top: 20px;
        }
        #raceAgainBtn:hover { transform: translateY(-1px); box-shadow: 0 4px 15px rgba(233, 69, 96, 0.4); }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Typing Speed Race</h1>
        <div class="race-code" id="raceCodeDisplay">#{code}</div>
      </div>
      <div class="checkered"></div>

      <div class="main">
        <div id="waiting">
          <h2>Waiting for Players...</h2>
          <div class="player-list" id="playerList"></div>
          <button id="startBtn" onclick="startRace()">Start Race</button>
          <p class="share-hint">Share the code <strong>#{code}</strong> with your friends to join</p>
        </div>

        <div id="countdown">
          <div class="number" id="countdownNumber">3</div>
        </div>

        <div id="racing">
          <div class="timer" id="timer">0:00</div>
          <div class="text-display" id="textDisplay"></div>
          <input type="text" id="typeInput" placeholder="Start typing when the race begins..." autocomplete="off" autocorrect="off" autocapitalize="off" spellcheck="false" />
          <div class="progress-section" id="progressSection"></div>
        </div>

        <div id="results">
          <h2>Race Complete!</h2>
          <div class="podium" id="podium"></div>
          <button id="raceAgainBtn" onclick="window.location.href='/'">Race Again</button>
        </div>
      </div>

      <script>
        var raceCode = #{Jason.encode!(code)};
        var params = new URLSearchParams(window.location.search);
        var playerName = params.get('name') || 'Anonymous';
        var isHost = params.get('host') === '1';
        var ws;
        var raceText = '';
        var raceStartTime = null;
        var timerInterval = null;
        var finished = false;
        var playerColors = {};
        var colorIndex = 0;

        function escapeHtml(text) {
          var div = document.createElement('div');
          div.appendChild(document.createTextNode(text));
          return div.innerHTML;
        }

        function connect() {
          var protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(protocol + '//' + location.host + '/ws/race/' + raceCode + '?name=' + encodeURIComponent(playerName));

          ws.onopen = function() {
            console.log('Connected to race ' + raceCode);
          };

          ws.onmessage = function(event) {
            var msg = JSON.parse(event.data);
            handleMessage(msg);
          };

          ws.onclose = function() {
            console.log('Disconnected');
          };
        }

        function handleMessage(msg) {
          switch (msg.type) {
            case 'player_joined': updatePlayerList(msg.players); break;
            case 'countdown': showCountdown(msg.seconds); break;
            case 'race_start': startTyping(msg.text); break;
            case 'progress': updateProgress(msg.players); break;
            case 'player_finished': break;
            case 'race_over': showResults(msg.results); break;
            case 'error': alert(msg.message); break;
          }
        }

        function updatePlayerList(players) {
          var list = document.getElementById('playerList');
          while (list.firstChild) { list.removeChild(list.firstChild); }
          players.forEach(function(p) {
            if (playerColors[p.name] === undefined) {
              playerColors[p.name] = colorIndex++;
            }
            var tag = document.createElement('div');
            tag.className = 'player-tag';
            var dot = document.createElement('span');
            dot.className = 'dot';
            tag.appendChild(dot);
            tag.appendChild(document.createTextNode(p.name));
            list.appendChild(tag);
          });

          var startBtn = document.getElementById('startBtn');
          if (isHost && players.length >= 2) {
            startBtn.style.display = 'inline-block';
          }
        }

        function startRace() {
          ws.send(JSON.stringify({type: 'start'}));
          document.getElementById('startBtn').disabled = true;
        }

        function showCountdown(seconds) {
          document.getElementById('waiting').style.display = 'none';
          document.getElementById('countdown').style.display = 'block';
          var numEl = document.getElementById('countdownNumber');
          numEl.textContent = seconds;
          numEl.style.animation = 'none';
          void numEl.offsetHeight;
          numEl.style.animation = 'pulse 0.5s ease-in-out';
        }

        function startTyping(text) {
          raceText = text;
          raceStartTime = Date.now();

          document.getElementById('countdown').style.display = 'none';
          document.getElementById('racing').style.display = 'block';

          renderText(0, '');
          var input = document.getElementById('typeInput');
          input.value = '';
          input.disabled = false;
          input.focus();

          input.addEventListener('input', onType);

          timerInterval = setInterval(updateTimer, 100);
        }

        function onType() {
          if (finished) return;
          var input = document.getElementById('typeInput');
          var typed = input.value;
          var position = typed.length;

          renderText(position, typed);

          ws.send(JSON.stringify({
            type: 'progress',
            typed: typed,
            position: position
          }));

          if (typed === raceText) {
            finished = true;
            var timeMs = Date.now() - raceStartTime;
            ws.send(JSON.stringify({type: 'finished', time_ms: timeMs}));
            input.disabled = true;
            clearInterval(timerInterval);
          }
        }

        function renderText(position, typed) {
          var display = document.getElementById('textDisplay');
          while (display.firstChild) { display.removeChild(display.firstChild); }
          for (var i = 0; i < raceText.length; i++) {
            var span = document.createElement('span');
            if (raceText[i] === ' ') {
              span.appendChild(document.createTextNode('\\u00A0'));
            } else {
              span.appendChild(document.createTextNode(raceText[i]));
            }
            if (i < position) {
              span.className = (typed[i] === raceText[i]) ? 'correct' : 'err';
            } else if (i === position) {
              span.className = 'current';
            } else {
              span.className = 'upcoming';
            }
            display.appendChild(span);
          }
        }

        function updateTimer() {
          if (!raceStartTime) return;
          var elapsed = Date.now() - raceStartTime;
          var seconds = Math.floor(elapsed / 1000);
          var minutes = Math.floor(seconds / 60);
          var secs = seconds % 60;
          document.getElementById('timer').textContent =
            minutes + ':' + (secs < 10 ? '0' : '') + secs;
        }

        function updateProgress(players) {
          var section = document.getElementById('progressSection');
          while (section.firstChild) { section.removeChild(section.firstChild); }
          players.forEach(function(p) {
            if (playerColors[p.name] === undefined) {
              playerColors[p.name] = colorIndex++;
            }
            var ci = playerColors[p.name] % 4;
            var container = document.createElement('div');
            container.className = 'progress-bar-container';

            var info = document.createElement('div');
            info.className = 'progress-info';
            var nameSpan = document.createElement('span');
            nameSpan.className = 'progress-name';
            nameSpan.textContent = p.name + (p.name === playerName ? ' (you)' : '');
            var statsSpan = document.createElement('span');
            statsSpan.className = 'progress-stats';
            statsSpan.textContent = p.percent + '% | ' + p.wpm + ' WPM';
            info.appendChild(nameSpan);
            info.appendChild(statsSpan);

            var track = document.createElement('div');
            track.className = 'progress-track';
            var fill = document.createElement('div');
            fill.className = 'progress-fill color-' + ci;
            fill.style.width = p.percent + '%';
            track.appendChild(fill);

            container.appendChild(info);
            container.appendChild(track);
            section.appendChild(container);
          });
        }

        function showResults(results) {
          clearInterval(timerInterval);
          document.getElementById('racing').style.display = 'none';
          document.getElementById('results').style.display = 'block';

          var podium = document.getElementById('podium');
          while (podium.firstChild) { podium.removeChild(podium.firstChild); }

          var medals = ['1st', '2nd', '3rd'];
          var classes = ['first', 'second', 'third'];

          results.slice(0, 3).forEach(function(r, i) {
            var place = document.createElement('div');
            place.className = 'podium-place ' + (classes[i] || '');

            var posDiv = document.createElement('div');
            posDiv.className = 'podium-position';
            posDiv.textContent = medals[i] || ((i + 1) + 'th');
            place.appendChild(posDiv);

            var nameDiv = document.createElement('div');
            nameDiv.className = 'podium-name';
            nameDiv.textContent = r.name;
            place.appendChild(nameDiv);

            var wpmDiv = document.createElement('div');
            wpmDiv.className = 'podium-wpm';
            wpmDiv.textContent = r.wpm + ' WPM';
            place.appendChild(wpmDiv);

            var timeDiv = document.createElement('div');
            timeDiv.className = 'podium-time';
            timeDiv.textContent = r.time_ms ? (r.time_ms / 1000).toFixed(1) + 's' : 'DNF';
            place.appendChild(timeDiv);

            podium.appendChild(place);
          });
        }

        connect();
      </script>
    </body>
    </html>
    """
  end
end
