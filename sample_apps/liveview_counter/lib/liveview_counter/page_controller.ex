defmodule LiveviewCounter.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Hibana LiveView Counter</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px; text-align: center; }
        .counter { font-size: 72px; margin: 20px 0; color: #333; }
        .buttons { display: flex; gap: 20px; justify-content: center; }
        button {
          padding: 15px 30px;
          font-size: 24px;
          cursor: pointer;
          border: none;
          border-radius: 8px;
          background: #0066cc;
          color: white;
        }
        button:hover { background: #0055aa; }
        button.reset { background: #cc0000; }
        button.reset:hover { background: #aa0000; }
        .auto-controls { margin-top: 20px; }
        .auto-controls button { font-size: 16px; padding: 10px 20px; }
        .status { margin-top: 20px; color: #666; }
      </style>
    </head>
    <body>
      <h1>LiveView Counter Demo</h1>
      <div class="counter" id="count">0</div>
      <div class="buttons">
        <button id="decrement">-</button>
        <button id="increment">+</button>
      </div>
      <div class="auto-controls">
        <button id="start-auto">Auto Increment</button>
        <button id="stop-auto" style="display:none;">Stop</button>
        <button id="reset" class="reset">Reset</button>
      </div>
      <div class="status" id="status">Connected</div>
      <script>
        let count = 0;
        let autoInterval = null;
        const countEl = document.getElementById("count");
        const statusEl = document.getElementById("status");
        const startBtn = document.getElementById("start-auto");
        const stopBtn = document.getElementById("stop-auto");

        const ws = new WebSocket("ws://" + location.host + "/live/counter");

        ws.onopen = () => { statusEl.textContent = "Connected"; };
        ws.onclose = () => { statusEl.textContent = "Disconnected"; };

        ws.onmessage = (event) => {
          const data = JSON.parse(event.data);
          if (data.count !== undefined) {
            count = data.count;
            countEl.textContent = count;
          }
        };

        document.getElementById("increment").onclick = () => {
          ws.send(JSON.stringify({event: "increment"}));
        };

        document.getElementById("decrement").onclick = () => {
          ws.send(JSON.stringify({event: "decrement"}));
        };

        document.getElementById("reset").onclick = () => {
          ws.send(JSON.stringify({event: "reset"}));
        };

        startBtn.onclick = () => {
          startBtn.style.display = "none";
          stopBtn.style.display = "inline-block";
          autoInterval = setInterval(() => {
            ws.send(JSON.stringify({event: "increment"}));
          }, 1000);
        };

        stopBtn.onclick = () => {
          clearInterval(autoInterval);
          startBtn.style.display = "inline-block";
          stopBtn.style.display = "none";
        };
      </script>
    </body>
    </html>
    """)
  end
end
