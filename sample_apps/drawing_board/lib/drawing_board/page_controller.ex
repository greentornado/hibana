defmodule DrawingBoard.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Drawing Board - Hibana</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #1a1a2e; color: #e0e0e0; min-height: 100vh; }
        .container { max-width: 800px; margin: 0 auto; padding: 40px 20px; }
        h1 { font-size: 2rem; margin-bottom: 8px; color: #fff; }
        .subtitle { color: #888; margin-bottom: 32px; }
        .create-form { display: flex; gap: 12px; margin-bottom: 32px; }
        .create-form input {
          flex: 1; padding: 12px 16px; border-radius: 8px; border: 1px solid #333;
          background: #16213e; color: #fff; font-size: 1rem; outline: none;
        }
        .create-form input:focus { border-color: #0f3460; }
        .create-form button {
          padding: 12px 24px; border-radius: 8px; border: none; background: #e94560;
          color: #fff; font-size: 1rem; cursor: pointer; font-weight: 600;
        }
        .create-form button:hover { background: #c73750; }
        .boards { display: grid; gap: 16px; }
        .board-card {
          background: #16213e; border-radius: 12px; padding: 20px;
          border: 1px solid #0f3460; cursor: pointer; transition: all 0.2s;
        }
        .board-card:hover { border-color: #e94560; transform: translateY(-2px); }
        .board-card h3 { font-size: 1.1rem; margin-bottom: 8px; color: #fff; }
        .board-meta { display: flex; gap: 16px; color: #888; font-size: 0.85rem; }
        .empty { text-align: center; padding: 60px; color: #666; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Collaborative Drawing Board</h1>
        <p class="subtitle">Create or join a board to draw together in real-time</p>
        <div class="create-form">
          <input type="text" id="board-name" placeholder="Board name..." />
          <button onclick="createBoard()">Create Board</button>
        </div>
        <div class="boards" id="boards">
          <div class="empty">Loading boards...</div>
        </div>
      </div>
      <script>
        function escapeHtml(str) {
          const d = document.createElement('div');
          d.textContent = str;
          return d.innerHTML;
        }

        function renderBoards(boards) {
          const container = document.getElementById('boards');
          container.textContent = '';
          if (boards.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'empty';
            empty.textContent = 'No boards yet. Create one to get started!';
            container.appendChild(empty);
            return;
          }
          boards.forEach(function(b) {
            const card = document.createElement('div');
            card.className = 'board-card';
            card.addEventListener('click', function() { location.href = '/board/' + encodeURIComponent(b.id); });
            var h3 = document.createElement('h3');
            h3.textContent = b.name;
            card.appendChild(h3);
            var meta = document.createElement('div');
            meta.className = 'board-meta';
            var strokes = document.createElement('span');
            strokes.textContent = b.stroke_count + ' strokes';
            meta.appendChild(strokes);
            var users = document.createElement('span');
            users.textContent = b.user_count + ' user' + (b.user_count !== 1 ? 's' : '') + ' online';
            meta.appendChild(users);
            card.appendChild(meta);
            container.appendChild(card);
          });
        }

        async function loadBoards() {
          var res = await fetch('/api/boards');
          var data = await res.json();
          renderBoards(data.boards);
        }

        async function createBoard() {
          var input = document.getElementById('board-name');
          var name = input.value.trim() || 'Untitled Board';
          var res = await fetch('/api/boards', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({name: name})
          });
          var data = await res.json();
          if (data.board) {
            location.href = '/board/' + data.board.id;
          }
        }

        document.getElementById('board-name').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') createBoard();
        });

        loadBoards();
        setInterval(loadBoards, 5000);
      </script>
    </body>
    </html>
    """)
  end

  def board(conn) do
    board_id = conn.params["id"]

    html(conn, board_html(board_id))
  end

  defp board_html(board_id) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Drawing Board</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #1a1a2e; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }

        #toolbar {
          position: fixed; top: 0; left: 0; right: 0; z-index: 10;
          background: rgba(22, 33, 62, 0.95); backdrop-filter: blur(8px);
          display: flex; align-items: center; gap: 12px; padding: 8px 16px;
          border-bottom: 1px solid #0f3460;
        }
        .toolbar-group { display: flex; align-items: center; gap: 8px; }
        .toolbar-divider { width: 1px; height: 28px; background: #333; margin: 0 4px; }
        .back-btn {
          background: none; border: none; color: #888; font-size: 1.2rem;
          cursor: pointer; padding: 4px 8px; text-decoration: none;
        }
        .back-btn:hover { color: #fff; }
        .board-title { color: #fff; font-size: 0.95rem; font-weight: 600; }

        .color-btn {
          width: 28px; height: 28px; border-radius: 50%; border: 2px solid transparent;
          cursor: pointer; transition: border-color 0.15s;
        }
        .color-btn.active { border-color: #fff; }
        .color-btn:hover { border-color: rgba(255,255,255,0.5); }

        #custom-color { width: 28px; height: 28px; border: none; border-radius: 50%; cursor: pointer; background: none; }

        .size-slider { width: 100px; accent-color: #e94560; }
        .size-label { color: #888; font-size: 0.8rem; min-width: 30px; }

        .tool-btn {
          background: #0f3460; border: 1px solid #333; color: #e0e0e0;
          padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: 0.85rem;
        }
        .tool-btn:hover { background: #e94560; border-color: #e94560; }

        #users-panel {
          position: fixed; top: 52px; right: 0; z-index: 10;
          background: rgba(22, 33, 62, 0.95); backdrop-filter: blur(8px);
          border-left: 1px solid #0f3460; border-bottom: 1px solid #0f3460;
          border-radius: 0 0 0 8px; padding: 8px 12px; min-width: 140px;
        }
        .users-title { color: #888; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px; }
        .user-item { color: #e0e0e0; font-size: 0.85rem; padding: 2px 0; }
        .user-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: #4ade80; margin-right: 6px; }

        #canvas { display: block; cursor: crosshair; }

        #status {
          position: fixed; bottom: 12px; left: 50%; transform: translateX(-50%);
          background: rgba(22, 33, 62, 0.9); color: #888; padding: 4px 16px;
          border-radius: 16px; font-size: 0.8rem; z-index: 10;
          transition: opacity 0.5s;
        }
      </style>
    </head>
    <body>
      <div id="toolbar">
        <a class="back-btn" href="/">&larr;</a>
        <span class="board-title" id="board-title">Drawing Board</span>
        <div class="toolbar-divider"></div>
        <div class="toolbar-group" id="colors"></div>
        <input type="color" id="custom-color" value="#ff6b6b" title="Custom color">
        <div class="toolbar-divider"></div>
        <input type="range" class="size-slider" id="brush-size" min="1" max="20" value="3">
        <span class="size-label" id="size-label">3px</span>
        <div class="toolbar-divider"></div>
        <button class="tool-btn" id="undo-btn">Undo</button>
        <button class="tool-btn" id="clear-btn">Clear</button>
      </div>

      <div id="users-panel">
        <div class="users-title">Online</div>
        <div id="users-list"></div>
      </div>

      <canvas id="canvas"></canvas>
      <div id="status">Connecting...</div>

      <script>
        var BOARD_ID = '#{board_id}';
        var COLORS = ['#ffffff','#e94560','#ff6b6b','#feca57','#48dbfb','#0abde3','#10ac84','#a55eea'];
        var currentColor = '#ffffff';
        var brushSize = 3;
        var drawing = false;
        var lastX = 0, lastY = 0;
        var ws = null;
        var userName = '';

        // Canvas setup
        var canvas = document.getElementById('canvas');
        var ctx = canvas.getContext('2d');

        function resizeCanvas() {
          canvas.width = window.innerWidth;
          canvas.height = window.innerHeight;
          ctx.lineCap = 'round';
          ctx.lineJoin = 'round';
        }
        resizeCanvas();
        window.addEventListener('resize', resizeCanvas);

        // Color picker
        var colorsDiv = document.getElementById('colors');
        COLORS.forEach(function(c) {
          var btn = document.createElement('button');
          btn.className = 'color-btn' + (c === currentColor ? ' active' : '');
          btn.style.background = c;
          btn.setAttribute('data-color', c);
          btn.addEventListener('click', function() { selectColor(c); });
          colorsDiv.appendChild(btn);
        });

        document.getElementById('custom-color').addEventListener('input', function(e) {
          selectColor(e.target.value);
        });

        function selectColor(c) {
          currentColor = c;
          var btns = document.querySelectorAll('.color-btn');
          btns.forEach(function(b) { b.classList.remove('active'); });
          var match = document.querySelector('.color-btn[data-color="' + c + '"]');
          if (match) match.classList.add('active');
        }

        // Brush size
        var sizeSlider = document.getElementById('brush-size');
        var sizeLabel = document.getElementById('size-label');
        sizeSlider.addEventListener('input', function() {
          brushSize = parseInt(sizeSlider.value);
          sizeLabel.textContent = brushSize + 'px';
        });

        // Drawing
        function getPos(e) {
          if (e.touches) return { x: e.touches[0].clientX, y: e.touches[0].clientY };
          return { x: e.clientX, y: e.clientY };
        }

        function startDraw(e) {
          e.preventDefault();
          drawing = true;
          var pos = getPos(e);
          lastX = pos.x;
          lastY = pos.y;
        }

        function moveDraw(e) {
          if (!drawing) return;
          e.preventDefault();
          var pos = getPos(e);
          drawLine(lastX, lastY, pos.x, pos.y, currentColor, brushSize);
          sendDraw(lastX, lastY, pos.x, pos.y, currentColor, brushSize);
          lastX = pos.x;
          lastY = pos.y;
        }

        function stopDraw(e) {
          if (e) e.preventDefault();
          drawing = false;
        }

        canvas.addEventListener('mousedown', startDraw);
        canvas.addEventListener('mousemove', moveDraw);
        canvas.addEventListener('mouseup', stopDraw);
        canvas.addEventListener('mouseleave', stopDraw);
        canvas.addEventListener('touchstart', startDraw, {passive: false});
        canvas.addEventListener('touchmove', moveDraw, {passive: false});
        canvas.addEventListener('touchend', stopDraw);

        function drawLine(x1, y1, x2, y2, color, width) {
          ctx.strokeStyle = color;
          ctx.lineWidth = width;
          ctx.beginPath();
          ctx.moveTo(x1, y1);
          ctx.lineTo(x2, y2);
          ctx.stroke();
        }

        // User list (safe DOM construction)
        function updateUsers(users) {
          var list = document.getElementById('users-list');
          list.textContent = '';
          users.forEach(function(u) {
            var item = document.createElement('div');
            item.className = 'user-item';
            var dot = document.createElement('span');
            dot.className = 'user-dot';
            item.appendChild(dot);
            item.appendChild(document.createTextNode(u));
            list.appendChild(item);
          });
        }

        // WebSocket
        function connect() {
          userName = prompt('Enter your name:') || 'Anonymous';
          openSocket();
        }

        function openSocket() {
          var proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(proto + '//' + location.host + '/ws/board/' + BOARD_ID + '?name=' + encodeURIComponent(userName));

          ws.onopen = function() {
            var status = document.getElementById('status');
            status.textContent = 'Connected as ' + userName;
            setTimeout(function() { status.style.opacity = '0'; }, 2000);
          };

          ws.onmessage = function(e) {
            var msg = JSON.parse(e.data);
            handleServerMessage(msg);
          };

          ws.onclose = function() {
            var status = document.getElementById('status');
            status.style.opacity = '1';
            status.textContent = 'Disconnected. Reconnecting...';
            setTimeout(openSocket, 2000);
          };
        }

        function handleServerMessage(msg) {
          switch (msg.type) {
            case 'draw':
              drawLine(msg.x1, msg.y1, msg.x2, msg.y2, msg.color, msg.width);
              break;
            case 'history':
              ctx.clearRect(0, 0, canvas.width, canvas.height);
              (msg.strokes || []).forEach(function(s) {
                drawLine(s.x1, s.y1, s.x2, s.y2, s.color, s.width);
              });
              if (msg.users) updateUsers(msg.users);
              break;
            case 'clear':
              ctx.clearRect(0, 0, canvas.width, canvas.height);
              break;
            case 'user_joined':
              updateUsers(msg.users);
              break;
            case 'user_left':
              updateUsers(msg.users);
              break;
          }
        }

        // Send messages
        function sendDraw(x1, y1, x2, y2, color, width) {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({type:'draw', x1:x1, y1:y1, x2:x2, y2:y2, color:color, width:width}));
          }
        }

        function sendClear() {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({type:'clear'}));
          }
        }

        function sendUndo() {
          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({type:'undo'}));
          }
        }

        document.getElementById('undo-btn').addEventListener('click', sendUndo);
        document.getElementById('clear-btn').addEventListener('click', sendClear);

        connect();
      </script>
    </body>
    </html>
    """
  end
end
