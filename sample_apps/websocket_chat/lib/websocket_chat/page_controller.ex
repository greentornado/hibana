defmodule WebsocketChat.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Hibana Chat</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        #messages { border: 1px solid #ccc; height: 300px; overflow-y: scroll; padding: 10px; margin-bottom: 10px; }
        #input { width: 70%; padding: 10px; }
        #send { width: 25%; padding: 10px; }
        .message { margin: 5px 0; }
        .system { color: #888; font-style: italic; }
        .user { color: #0066cc; }
      </style>
    </head>
    <body>
      <h1>Hibana WebSocket Chat</h1>
      <div id="messages"></div>
      <input type="text" id="input" placeholder="Type a message..." />
      <button id="send">Send</button>
      <script>
        const ws = new WebSocket("ws://localhost:4003/chat");
        const messages = document.getElementById("messages");
        const input = document.getElementById("input");
        const send = document.getElementById("send");

        ws.onopen = () => {
          addMessage("Connected to chat server", "system");
        };

        ws.onmessage = (event) => {
          addMessage(event.data, "user");
        };

        ws.onclose = () => {
          addMessage("Disconnected from chat server", "system");
        };

        send.onclick = () => {
          if (input.value) {
            ws.send(input.value);
            input.value = "";
          }
        };

        input.onkeypress = (e) => {
          if (e.key === "Enter" && input.value) {
            ws.send(input.value);
            input.value = "";
          }
        };

        function addMessage(text, type) {
          const div = document.createElement("div");
          div.className = "message " + type;
          div.textContent = text;
          messages.appendChild(div);
          messages.scrollTop = messages.scrollHeight;
        }
      </script>
    </body>
    </html>
    """)
  end
end
