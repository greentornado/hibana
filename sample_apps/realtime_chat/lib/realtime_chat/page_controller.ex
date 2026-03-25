defmodule RealtimeChat.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Hibana Realtime Chat</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #1a1a2e;
          color: #e0e0e0;
          height: 100vh;
          display: flex;
          flex-direction: column;
        }

        /* Top bar */
        .top-bar {
          background: #16213e;
          padding: 12px 20px;
          display: flex;
          align-items: center;
          gap: 16px;
          border-bottom: 1px solid #0f3460;
        }
        .top-bar h1 {
          font-size: 18px;
          color: #e94560;
          flex-shrink: 0;
        }
        .status {
          font-size: 12px;
          padding: 4px 8px;
          border-radius: 10px;
        }
        .status.connected { background: #1b4332; color: #52b788; }
        .status.disconnected { background: #3d0000; color: #e94560; }
        .username-area {
          display: flex;
          align-items: center;
          gap: 8px;
          margin-left: auto;
        }
        .username-area label { font-size: 13px; color: #888; }

        /* Main layout */
        .main {
          display: flex;
          flex: 1;
          overflow: hidden;
        }

        /* Sidebar */
        .sidebar {
          width: 240px;
          background: #16213e;
          border-right: 1px solid #0f3460;
          display: flex;
          flex-direction: column;
        }
        .sidebar-header {
          padding: 14px 16px;
          font-size: 13px;
          font-weight: 600;
          color: #888;
          text-transform: uppercase;
          letter-spacing: 1px;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }
        .sidebar-header button {
          background: none;
          border: 1px solid #0f3460;
          color: #e94560;
          padding: 4px 10px;
          border-radius: 4px;
          cursor: pointer;
          font-size: 12px;
        }
        .sidebar-header button:hover { background: #1a1a2e; }
        .room-list {
          flex: 1;
          overflow-y: auto;
          list-style: none;
        }
        .room-list li {
          padding: 10px 16px;
          cursor: pointer;
          font-size: 14px;
          display: flex;
          align-items: center;
          gap: 8px;
          transition: background 0.15s;
        }
        .room-list li:hover { background: #1a1a2e; }
        .room-list li.active { background: #0f3460; color: #e94560; }
        .room-list li .room-hash { color: #555; }
        .room-list li .user-count {
          margin-left: auto;
          font-size: 11px;
          color: #666;
          background: #1a1a2e;
          padding: 2px 6px;
          border-radius: 8px;
        }

        /* Presence sidebar */
        .presence-panel {
          width: 180px;
          background: #16213e;
          border-left: 1px solid #0f3460;
          display: flex;
          flex-direction: column;
        }
        .presence-header {
          padding: 14px 16px;
          font-size: 13px;
          font-weight: 600;
          color: #888;
          text-transform: uppercase;
          letter-spacing: 1px;
        }
        .user-list {
          flex: 1;
          overflow-y: auto;
          list-style: none;
        }
        .user-list li {
          padding: 6px 16px;
          font-size: 13px;
          display: flex;
          align-items: center;
          gap: 8px;
        }
        .user-list li .dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: #52b788;
        }

        /* Chat area */
        .chat-area {
          flex: 1;
          display: flex;
          flex-direction: column;
        }
        .chat-header {
          padding: 14px 20px;
          border-bottom: 1px solid #0f3460;
          font-size: 16px;
          font-weight: 600;
        }
        .chat-header span { color: #e94560; }
        .messages {
          flex: 1;
          overflow-y: auto;
          padding: 16px 20px;
          display: flex;
          flex-direction: column;
          gap: 4px;
        }
        .message {
          padding: 6px 0;
          font-size: 14px;
          line-height: 1.5;
        }
        .message .msg-user {
          font-weight: 600;
          color: #e94560;
          margin-right: 8px;
        }
        .message .msg-time {
          font-size: 11px;
          color: #555;
          margin-left: 8px;
        }
        .message.system {
          color: #555;
          font-style: italic;
          font-size: 12px;
        }

        /* Input area */
        .input-area {
          padding: 16px 20px;
          border-top: 1px solid #0f3460;
          display: flex;
          gap: 10px;
        }
        .input-area input {
          flex: 1;
          background: #16213e;
          border: 1px solid #0f3460;
          color: #e0e0e0;
          padding: 10px 14px;
          border-radius: 6px;
          font-size: 14px;
          outline: none;
        }
        .input-area input:focus { border-color: #e94560; }
        .input-area button {
          background: #e94560;
          color: white;
          border: none;
          padding: 10px 20px;
          border-radius: 6px;
          cursor: pointer;
          font-size: 14px;
          font-weight: 600;
        }
        .input-area button:hover { background: #c73e54; }

        /* No room selected */
        .no-room {
          flex: 1;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #555;
          font-size: 16px;
        }

        /* Modal */
        .modal-overlay {
          display: none;
          position: fixed;
          top: 0; left: 0; right: 0; bottom: 0;
          background: rgba(0,0,0,0.6);
          z-index: 100;
          align-items: center;
          justify-content: center;
        }
        .modal-overlay.show { display: flex; }
        .modal {
          background: #16213e;
          border: 1px solid #0f3460;
          border-radius: 8px;
          padding: 24px;
          width: 360px;
        }
        .modal h2 { font-size: 16px; margin-bottom: 16px; color: #e94560; }
        .modal input {
          width: 100%;
          background: #1a1a2e;
          border: 1px solid #0f3460;
          color: #e0e0e0;
          padding: 10px;
          border-radius: 4px;
          font-size: 14px;
          margin-bottom: 16px;
        }
        .modal .modal-actions {
          display: flex;
          gap: 10px;
          justify-content: flex-end;
        }
        .modal button {
          padding: 8px 16px;
          border-radius: 4px;
          border: none;
          cursor: pointer;
          font-size: 13px;
        }
        .modal .btn-primary { background: #e94560; color: white; }
        .modal .btn-cancel { background: #333; color: #ccc; }

        /* Scrollbar */
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #333; border-radius: 3px; }

        /* Username prompt overlay */
        .username-prompt {
          position: fixed;
          top: 0; left: 0; right: 0; bottom: 0;
          background: #1a1a2e;
          z-index: 200;
          display: flex;
          align-items: center;
          justify-content: center;
        }
        .username-prompt.hidden { display: none; }
        .username-prompt .prompt-box { text-align: center; }
        .username-prompt h1 { color: #e94560; margin-bottom: 8px; }
        .username-prompt p { color: #888; margin-bottom: 24px; font-size: 14px; }
        .username-prompt input {
          background: #16213e;
          border: 1px solid #0f3460;
          color: #e0e0e0;
          padding: 12px 16px;
          border-radius: 6px;
          font-size: 16px;
          width: 280px;
          text-align: center;
          margin-bottom: 16px;
          display: block;
        }
        .username-prompt button {
          background: #e94560;
          color: white;
          border: none;
          padding: 12px 32px;
          border-radius: 6px;
          cursor: pointer;
          font-size: 16px;
          font-weight: 600;
        }
        .username-prompt button:hover { background: #c73e54; }
      </style>
    </head>
    <body>
      <!-- Username prompt -->
      <div class="username-prompt" id="usernamePrompt">
        <div class="prompt-box">
          <h1>Hibana Chat</h1>
          <p>Enter your username to get started</p>
          <input type="text" id="usernameInput" placeholder="Username" maxlength="20" autofocus />
          <br>
          <button id="usernameBtn">Join Chat</button>
        </div>
      </div>

      <!-- Top bar -->
      <div class="top-bar">
        <h1>Hibana Chat</h1>
        <span class="status disconnected" id="statusBadge">Disconnected</span>
        <div class="username-area">
          <label>Logged in as:</label>
          <span id="currentUser" style="color: #e94560; font-weight: 600;">-</span>
        </div>
      </div>

      <!-- Main layout -->
      <div class="main">
        <!-- Sidebar: room list -->
        <div class="sidebar">
          <div class="sidebar-header">
            Rooms
            <button id="newRoomBtn">+ New</button>
          </div>
          <ul class="room-list" id="roomList"></ul>
        </div>

        <!-- Chat area -->
        <div class="chat-area" id="chatArea">
          <div class="no-room" id="noRoom">Select a room to start chatting</div>
          <div class="chat-header" id="chatHeader" style="display:none;">
            <span>#</span> <span id="chatRoomName"></span>
          </div>
          <div class="messages" id="messages" style="display:none;"></div>
          <div class="input-area" id="inputArea" style="display:none;">
            <input type="text" id="msgInput" placeholder="Type a message..." />
            <button id="sendBtn">Send</button>
          </div>
        </div>

        <!-- Presence panel -->
        <div class="presence-panel" id="presencePanel" style="display:none;">
          <div class="presence-header">Online &mdash; <span id="onlineCount">0</span></div>
          <ul class="user-list" id="userList"></ul>
        </div>
      </div>

      <!-- Create room modal -->
      <div class="modal-overlay" id="createRoomModal">
        <div class="modal">
          <h2>Create New Room</h2>
          <input type="text" id="newRoomName" placeholder="Room name" maxlength="30" />
          <div class="modal-actions">
            <button class="btn-cancel" id="cancelRoomBtn">Cancel</button>
            <button class="btn-primary" id="createRoomBtn">Create</button>
          </div>
        </div>
      </div>

      <script>
        (function() {
          var ws = null;
          var username = localStorage.getItem('chat_username') || '';
          var currentRoom = null;
          var rooms = [];
          var presenceMap = {};
          var messageMap = {};

          // DOM refs
          var usernamePrompt = document.getElementById('usernamePrompt');
          var usernameInput = document.getElementById('usernameInput');
          var currentUserEl = document.getElementById('currentUser');
          var statusBadge = document.getElementById('statusBadge');
          var roomListEl = document.getElementById('roomList');
          var noRoomEl = document.getElementById('noRoom');
          var chatHeader = document.getElementById('chatHeader');
          var chatRoomName = document.getElementById('chatRoomName');
          var messagesEl = document.getElementById('messages');
          var inputArea = document.getElementById('inputArea');
          var msgInput = document.getElementById('msgInput');
          var presencePanel = document.getElementById('presencePanel');
          var onlineCount = document.getElementById('onlineCount');
          var userListEl = document.getElementById('userList');
          var createRoomModal = document.getElementById('createRoomModal');
          var newRoomNameInput = document.getElementById('newRoomName');

          function escapeHtml(text) {
            var div = document.createElement('div');
            div.textContent = text || '';
            return div.innerHTML;
          }

          // Username prompt
          if (username) {
            usernamePrompt.classList.add('hidden');
            currentUserEl.textContent = username;
            connect();
            loadRooms();
          }

          document.getElementById('usernameBtn').addEventListener('click', setUsername);
          usernameInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') setUsername();
          });

          function setUsername() {
            var name = usernameInput.value.trim();
            if (!name) return;
            username = name;
            localStorage.setItem('chat_username', username);
            usernamePrompt.classList.add('hidden');
            currentUserEl.textContent = username;
            connect();
            loadRooms();
          }

          // WebSocket
          function connect() {
            var proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
            ws = new WebSocket(proto + '//' + location.host + '/ws/chat?username=' + encodeURIComponent(username));

            ws.onopen = function() {
              statusBadge.textContent = 'Connected';
              statusBadge.className = 'status connected';
              if (currentRoom) {
                ws.send(JSON.stringify({type: 'join_room', room: currentRoom}));
              }
            };

            ws.onmessage = function(event) {
              handleMessage(JSON.parse(event.data));
            };

            ws.onclose = function() {
              statusBadge.textContent = 'Disconnected';
              statusBadge.className = 'status disconnected';
              setTimeout(connect, 2000);
            };

            ws.onerror = function() {};
          }

          function handleMessage(data) {
            switch (data.type) {
              case 'message':
                addChatMessage(data.room, data);
                break;
              case 'history':
                messageMap[data.room] = data.messages || [];
                renderMessages();
                break;
              case 'user_joined':
                addSystemMessage(data.room, data.user + ' joined the room');
                break;
              case 'user_left':
                addSystemMessage(data.room, data.user + ' left the room');
                break;
              case 'presence':
                presenceMap[data.room] = data.users || [];
                if (data.room === currentRoom) renderPresence();
                updateRoomList();
                break;
              case 'left_room':
                break;
              case 'error':
                console.error('Server error:', data.message);
                break;
            }
          }

          function addChatMessage(room, msg) {
            if (!messageMap[room]) messageMap[room] = [];
            messageMap[room].push(msg);
            if (messageMap[room].length > 100) {
              messageMap[room] = messageMap[room].slice(-100);
            }
            if (room === currentRoom) renderMessages();
          }

          function addSystemMessage(room, text) {
            addChatMessage(room, {type: 'system', text: text, timestamp: new Date().toISOString()});
          }

          function renderMessages() {
            var msgs = messageMap[currentRoom] || [];
            messagesEl.textContent = '';
            msgs.forEach(function(msg) {
              var div = document.createElement('div');
              if (msg.type === 'system') {
                div.className = 'message system';
                div.textContent = msg.text;
              } else {
                div.className = 'message';
                var userSpan = document.createElement('span');
                userSpan.className = 'msg-user';
                userSpan.textContent = msg.user;
                var textNode = document.createTextNode(msg.text || '');
                var timeSpan = document.createElement('span');
                timeSpan.className = 'msg-time';
                timeSpan.textContent = msg.timestamp ? new Date(msg.timestamp).toLocaleTimeString() : '';
                div.appendChild(userSpan);
                div.appendChild(textNode);
                div.appendChild(timeSpan);
              }
              messagesEl.appendChild(div);
            });
            messagesEl.scrollTop = messagesEl.scrollHeight;
          }

          function renderPresence() {
            var users = presenceMap[currentRoom] || [];
            onlineCount.textContent = users.length;
            userListEl.textContent = '';
            users.forEach(function(u) {
              var li = document.createElement('li');
              var dot = document.createElement('span');
              dot.className = 'dot';
              li.appendChild(dot);
              li.appendChild(document.createTextNode(u));
              userListEl.appendChild(li);
            });
          }

          // Room management
          function loadRooms() {
            fetch('/api/rooms')
              .then(function(r) { return r.json(); })
              .then(function(data) {
                rooms = data.rooms || [];
                updateRoomList();
              });
          }

          function updateRoomList() {
            roomListEl.textContent = '';
            rooms.forEach(function(room) {
              var li = document.createElement('li');
              li.className = room.id === currentRoom ? 'active' : '';
              var hash = document.createElement('span');
              hash.className = 'room-hash';
              hash.textContent = '#';
              li.appendChild(hash);
              li.appendChild(document.createTextNode(' ' + room.name));
              var count = (presenceMap[room.id] || []).length;
              if (count > 0) {
                var countSpan = document.createElement('span');
                countSpan.className = 'user-count';
                countSpan.textContent = count;
                li.appendChild(countSpan);
              }
              li.addEventListener('click', function() { joinRoom(room.id, room.name); });
              roomListEl.appendChild(li);
            });
          }

          function joinRoom(roomId, roomName) {
            if (currentRoom === roomId) return;

            if (currentRoom && ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({type: 'leave_room', room: currentRoom}));
            }

            currentRoom = roomId;
            noRoomEl.style.display = 'none';
            chatHeader.style.display = '';
            messagesEl.style.display = '';
            inputArea.style.display = '';
            presencePanel.style.display = '';
            chatRoomName.textContent = roomName;

            renderMessages();
            renderPresence();

            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({type: 'join_room', room: roomId}));
            }

            updateRoomList();
          }

          function sendMessage() {
            var text = msgInput.value.trim();
            if (!text || !currentRoom) return;
            if (ws && ws.readyState === WebSocket.OPEN) {
              ws.send(JSON.stringify({type: 'message', room: currentRoom, text: text}));
              msgInput.value = '';
            }
          }

          document.getElementById('sendBtn').addEventListener('click', sendMessage);
          msgInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') sendMessage();
          });

          // Create room
          document.getElementById('newRoomBtn').addEventListener('click', function() {
            createRoomModal.classList.add('show');
            newRoomNameInput.value = '';
            newRoomNameInput.focus();
          });

          document.getElementById('cancelRoomBtn').addEventListener('click', function() {
            createRoomModal.classList.remove('show');
          });

          document.getElementById('createRoomBtn').addEventListener('click', createRoom);
          newRoomNameInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') createRoom();
          });

          function createRoom() {
            var name = newRoomNameInput.value.trim();
            if (!name) return;

            fetch('/api/rooms', {
              method: 'POST',
              headers: {'Content-Type': 'application/json'},
              body: JSON.stringify({name: name})
            })
              .then(function(r) { return r.json(); })
              .then(function(data) {
                if (data.room) {
                  rooms.push(data.room);
                  updateRoomList();
                  createRoomModal.classList.remove('show');
                  joinRoom(data.room.id, data.room.name);
                } else if (data.error) {
                  alert(data.error);
                }
              });
          }
        })();
      </script>
    </body>
    </html>
    """)
  end
end
