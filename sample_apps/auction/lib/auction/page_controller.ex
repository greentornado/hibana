defmodule Auction.PageController do
  use Hibana.Controller

  def index(conn) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Hibana Auctions</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0f0f13;
          color: #e4e4e7;
          min-height: 100vh;
        }
        .header {
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          border-bottom: 1px solid #2a2a3e;
          padding: 20px 0;
        }
        .header-inner {
          max-width: 1200px;
          margin: 0 auto;
          padding: 0 24px;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .logo { font-size: 24px; font-weight: 700; color: #818cf8; }
        .logo span { color: #f59e0b; }
        .btn-create {
          background: #818cf8;
          color: #fff;
          border: none;
          padding: 10px 20px;
          border-radius: 8px;
          cursor: pointer;
          font-size: 14px;
          font-weight: 600;
        }
        .btn-create:hover { background: #6366f1; }
        .container { max-width: 1200px; margin: 0 auto; padding: 32px 24px; }
        h2 { font-size: 20px; margin-bottom: 20px; color: #a1a1aa; }
        .grid {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
          gap: 24px;
          margin-bottom: 40px;
        }
        .card {
          background: #1a1a2e;
          border: 1px solid #2a2a3e;
          border-radius: 12px;
          overflow: hidden;
          transition: transform 0.2s, box-shadow 0.2s;
          cursor: pointer;
          text-decoration: none;
          color: inherit;
          display: block;
        }
        .card:hover { transform: translateY(-4px); box-shadow: 0 8px 32px rgba(99, 102, 241, 0.15); }
        .card-img {
          height: 180px;
          background: linear-gradient(135deg, #2a2a3e 0%, #1e1e32 100%);
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 48px;
        }
        .card-body { padding: 20px; }
        .card-title { font-size: 18px; font-weight: 600; margin-bottom: 8px; }
        .card-desc { font-size: 13px; color: #71717a; margin-bottom: 16px; line-height: 1.5; }
        .card-meta { display: flex; justify-content: space-between; align-items: center; }
        .price { font-size: 22px; font-weight: 700; color: #4ade80; }
        .time-badge {
          background: #27272a;
          padding: 6px 12px;
          border-radius: 6px;
          font-size: 13px;
          font-weight: 600;
        }
        .time-badge.urgent { background: #7f1d1d; color: #fca5a5; }
        .time-badge.ended { background: #3f3f46; color: #71717a; }
        .bid-count { font-size: 12px; color: #71717a; margin-top: 8px; }
        .empty { text-align: center; color: #52525b; padding: 40px; font-size: 16px; }
        .toast-container {
          position: fixed;
          top: 20px;
          right: 20px;
          z-index: 1000;
        }
        .toast {
          background: #1e1e32;
          border: 1px solid #818cf8;
          border-radius: 8px;
          padding: 12px 20px;
          margin-bottom: 8px;
          animation: slideIn 0.3s ease, fadeOut 0.3s ease 2.7s;
          font-size: 14px;
        }
        @keyframes slideIn { from { transform: translateX(100px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        @keyframes fadeOut { from { opacity: 1; } to { opacity: 0; } }

        .modal-overlay {
          display: none;
          position: fixed;
          inset: 0;
          background: rgba(0,0,0,0.7);
          z-index: 100;
          align-items: center;
          justify-content: center;
        }
        .modal-overlay.active { display: flex; }
        .modal {
          background: #1a1a2e;
          border: 1px solid #2a2a3e;
          border-radius: 16px;
          padding: 32px;
          width: 90%;
          max-width: 480px;
        }
        .modal h3 { font-size: 20px; margin-bottom: 20px; }
        .form-group { margin-bottom: 16px; }
        .form-group label { display: block; font-size: 13px; color: #a1a1aa; margin-bottom: 6px; }
        .form-group input, .form-group textarea {
          width: 100%;
          background: #0f0f13;
          border: 1px solid #2a2a3e;
          border-radius: 8px;
          padding: 10px 14px;
          color: #e4e4e7;
          font-size: 14px;
          font-family: inherit;
        }
        .form-group textarea { resize: vertical; min-height: 80px; }
        .modal-actions { display: flex; gap: 12px; justify-content: flex-end; margin-top: 24px; }
        .btn-cancel {
          background: transparent;
          border: 1px solid #2a2a3e;
          color: #a1a1aa;
          padding: 10px 20px;
          border-radius: 8px;
          cursor: pointer;
          font-size: 14px;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <div class="header-inner">
          <div class="logo">Hibana <span>Auctions</span></div>
          <button class="btn-create" onclick="showCreateModal()">+ New Auction</button>
        </div>
      </div>

      <div class="container">
        <h2>Active Auctions</h2>
        <div id="active-grid" class="grid"></div>

        <h2>Recently Ended</h2>
        <div id="completed-grid" class="grid"></div>
      </div>

      <div class="toast-container" id="toasts"></div>

      <div class="modal-overlay" id="createModal">
        <div class="modal">
          <h3>Create New Auction</h3>
          <div class="form-group">
            <label>Title</label>
            <input type="text" id="create-title" placeholder="Item title" />
          </div>
          <div class="form-group">
            <label>Description</label>
            <textarea id="create-desc" placeholder="Describe the item..."></textarea>
          </div>
          <div class="form-group">
            <label>Starting Price ($)</label>
            <input type="number" id="create-price" value="10" min="1" />
          </div>
          <div class="form-group">
            <label>Duration (minutes)</label>
            <input type="number" id="create-duration" value="5" min="1" max="60" />
          </div>
          <div class="modal-actions">
            <button class="btn-cancel" onclick="hideCreateModal()">Cancel</button>
            <button class="btn-create" onclick="createAuction()">Create Auction</button>
          </div>
        </div>
      </div>

      <script>
        const icons = ['&#9201;', '&#128214;', '&#9823;', '&#127912;', '&#128142;', '&#127942;'];

        function escapeHtml(str) {
          if (!str) return '';
          var d = document.createElement('div');
          d.textContent = str;
          return d.innerHTML;
        }

        function formatTime(seconds) {
          if (seconds <= 0) return 'Ended';
          var m = Math.floor(seconds / 60);
          var s = seconds % 60;
          return m + ':' + String(s).padStart(2, '0');
        }

        function buildCard(a, icon) {
          var isActive = a.status === 'active';
          var link = document.createElement('a');
          link.className = 'card';
          link.href = '/auction/' + a.id;

          var imgDiv = document.createElement('div');
          imgDiv.className = 'card-img';
          imgDiv.textContent = icon;
          link.appendChild(imgDiv);

          var body = document.createElement('div');
          body.className = 'card-body';

          var title = document.createElement('div');
          title.className = 'card-title';
          title.textContent = a.title;
          body.appendChild(title);

          var desc = document.createElement('div');
          desc.className = 'card-desc';
          desc.textContent = (a.description || '').substring(0, 100);
          body.appendChild(desc);

          var meta = document.createElement('div');
          meta.className = 'card-meta';

          var price = document.createElement('div');
          price.className = 'price';
          price.textContent = '$' + a.current_price;
          meta.appendChild(price);

          var badge = document.createElement('div');
          var timeClass = !isActive ? 'ended' : (a.time_remaining < 60 ? 'urgent' : '');
          badge.className = 'time-badge ' + timeClass;
          badge.textContent = isActive ? formatTime(a.time_remaining) : 'Ended';
          meta.appendChild(badge);

          body.appendChild(meta);

          var bidInfo = document.createElement('div');
          bidInfo.className = 'bid-count';
          bidInfo.textContent = (a.bid_count || 0) + ' bids';
          if (a.highest_bidder) {
            bidInfo.textContent += ' / Leading: ' + a.highest_bidder;
          }
          body.appendChild(bidInfo);

          link.appendChild(body);
          return link;
        }

        function loadAuctions() {
          fetch('/api/auctions')
            .then(function(r) { return r.json(); })
            .then(function(data) {
              var auctions = data.auctions || [];
              var active = auctions.filter(function(a) { return a.status === 'active'; });
              var completed = auctions.filter(function(a) { return a.status !== 'active'; });

              var ag = document.getElementById('active-grid');
              ag.textContent = '';
              if (active.length === 0) {
                var empty = document.createElement('div');
                empty.className = 'empty';
                empty.textContent = 'No active auctions. Create one!';
                ag.appendChild(empty);
              } else {
                var iconChars = ['\\u23F1', '\\uD83D\\uDCD6', '\\u265F', '\\uD83C\\uDFA8', '\\uD83D\\uDC8E', '\\uD83C\\uDFC6'];
                active.forEach(function(a, i) {
                  ag.appendChild(buildCard(a, iconChars[i % iconChars.length]));
                });
              }

              var cg = document.getElementById('completed-grid');
              cg.textContent = '';
              if (completed.length === 0) {
                var empty2 = document.createElement('div');
                empty2.className = 'empty';
                empty2.textContent = 'No completed auctions yet.';
                cg.appendChild(empty2);
              } else {
                var iconChars2 = ['\\u23F1', '\\uD83D\\uDCD6', '\\u265F', '\\uD83C\\uDFA8', '\\uD83D\\uDC8E', '\\uD83C\\uDFC6'];
                completed.forEach(function(a, i) {
                  cg.appendChild(buildCard(a, iconChars2[i % iconChars2.length]));
                });
              }
            });
        }

        function showCreateModal() { document.getElementById('createModal').classList.add('active'); }
        function hideCreateModal() { document.getElementById('createModal').classList.remove('active'); }

        function createAuction() {
          var title = document.getElementById('create-title').value;
          var desc = document.getElementById('create-desc').value;
          var price = parseFloat(document.getElementById('create-price').value) || 10;
          var dur = parseInt(document.getElementById('create-duration').value) || 5;

          fetch('/api/auctions', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ title: title, description: desc, starting_price: price, duration_minutes: dur })
          })
          .then(function(r) { return r.json(); })
          .then(function(data) {
            hideCreateModal();
            if (data.auction) {
              window.location.href = '/auction/' + data.auction.id;
            }
          });
        }

        loadAuctions();
        setInterval(loadAuctions, 3000);
      </script>
    </body>
    </html>
    """)
  end

  def show(conn) do
    id = conn.params["id"]

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Auction Detail</title>
      <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #0f0f13;
          color: #e4e4e7;
          min-height: 100vh;
        }
        .header {
          background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
          border-bottom: 1px solid #2a2a3e;
          padding: 20px 0;
        }
        .header-inner {
          max-width: 1000px;
          margin: 0 auto;
          padding: 0 24px;
          display: flex;
          justify-content: space-between;
          align-items: center;
        }
        .logo { font-size: 24px; font-weight: 700; color: #818cf8; text-decoration: none; }
        .logo span { color: #f59e0b; }
        .container { max-width: 1000px; margin: 0 auto; padding: 32px 24px; }
        .auction-grid { display: grid; grid-template-columns: 1fr 360px; gap: 32px; }
        @media (max-width: 768px) { .auction-grid { grid-template-columns: 1fr; } }
        .title { font-size: 28px; font-weight: 700; margin-bottom: 12px; }
        .description { color: #a1a1aa; line-height: 1.7; margin-bottom: 24px; font-size: 15px; }
        .price-section {
          background: #1a1a2e;
          border: 1px solid #2a2a3e;
          border-radius: 16px;
          padding: 24px;
          margin-bottom: 24px;
        }
        .price-label { font-size: 13px; color: #71717a; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 4px; }
        .price-value { font-size: 48px; font-weight: 800; color: #4ade80; }
        .price-value.ended { color: #71717a; }
        .timer {
          font-size: 32px;
          font-weight: 700;
          color: #e4e4e7;
          margin-top: 16px;
        }
        .timer.urgent { color: #ef4444; animation: pulse 1s infinite; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.6; } }
        .timer-label { font-size: 13px; color: #71717a; text-transform: uppercase; letter-spacing: 1px; }
        .bid-info { display: flex; gap: 20px; margin-top: 16px; }
        .bid-stat { font-size: 13px; color: #a1a1aa; }
        .bid-stat strong { color: #e4e4e7; }
        .bid-form {
          background: #1a1a2e;
          border: 1px solid #2a2a3e;
          border-radius: 16px;
          padding: 24px;
          margin-bottom: 24px;
        }
        .bid-form h3 { font-size: 16px; margin-bottom: 16px; }
        .name-input {
          width: 100%;
          background: #0f0f13;
          border: 1px solid #2a2a3e;
          border-radius: 8px;
          padding: 10px 14px;
          color: #e4e4e7;
          font-size: 14px;
          margin-bottom: 12px;
        }
        .min-bid-hint { font-size: 12px; color: #71717a; margin-bottom: 12px; }
        .btn-bid {
          background: #4ade80;
          color: #0f0f13;
          border: none;
          padding: 12px 24px;
          border-radius: 8px;
          font-size: 16px;
          font-weight: 700;
          cursor: pointer;
          width: 100%;
        }
        .btn-bid:hover { background: #22c55e; }
        .btn-bid:disabled { background: #3f3f46; color: #71717a; cursor: not-allowed; }
        .bid-history {
          background: #1a1a2e;
          border: 1px solid #2a2a3e;
          border-radius: 16px;
          padding: 24px;
          max-height: 400px;
          overflow-y: auto;
        }
        .bid-history h3 { font-size: 16px; margin-bottom: 16px; }
        .bid-entry {
          display: flex;
          justify-content: space-between;
          align-items: center;
          padding: 10px 0;
          border-bottom: 1px solid #27272a;
          animation: fadeIn 0.3s ease;
        }
        .bid-entry:last-child { border-bottom: none; }
        .bid-entry .bidder { font-weight: 600; font-size: 14px; }
        .bid-entry .amount { color: #4ade80; font-weight: 700; font-size: 15px; }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(-8px); } to { opacity: 1; transform: translateY(0); } }
        .no-bids { color: #52525b; font-size: 14px; text-align: center; padding: 20px; }
        .winner-banner {
          background: linear-gradient(135deg, #854d0e, #a16207);
          border-radius: 12px;
          padding: 20px;
          text-align: center;
          margin-bottom: 24px;
          font-size: 18px;
          font-weight: 700;
        }
        .toast-container { position: fixed; top: 20px; right: 20px; z-index: 1000; }
        .toast {
          background: #1e1e32;
          border-left: 4px solid #818cf8;
          border-radius: 8px;
          padding: 12px 20px;
          margin-bottom: 8px;
          animation: slideIn 0.3s ease;
          font-size: 14px;
          min-width: 250px;
        }
        .toast.bid { border-left-color: #4ade80; }
        .toast.outbid { border-left-color: #ef4444; }
        .toast.ended { border-left-color: #f59e0b; }
        @keyframes slideIn { from { transform: translateX(100px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        .status-badge {
          display: inline-block;
          padding: 4px 12px;
          border-radius: 20px;
          font-size: 12px;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 1px;
        }
        .status-badge.active { background: #14532d; color: #4ade80; }
        .status-badge.ended { background: #27272a; color: #71717a; }
      </style>
    </head>
    <body>
      <div class="header">
        <div class="header-inner">
          <a class="logo" href="/">Hibana <span>Auctions</span></a>
          <span class="status-badge active" id="statusBadge">ACTIVE</span>
        </div>
      </div>

      <div class="container">
        <div id="winnerBanner" style="display:none;" class="winner-banner"></div>

        <div class="auction-grid">
          <div class="main-section">
            <h1 class="title" id="auctionTitle">Loading...</h1>
            <p class="description" id="auctionDesc"></p>

            <div class="price-section">
              <div class="price-label">Current Price</div>
              <div class="price-value" id="currentPrice">$0</div>
              <div style="margin-top:16px;">
                <div class="timer-label">Time Remaining</div>
                <div class="timer" id="timer">--:--</div>
              </div>
              <div class="bid-info">
                <div class="bid-stat"><strong id="bidCount">0</strong> bids</div>
                <div class="bid-stat">Leading: <strong id="leadingBidder">---</strong></div>
                <div class="bid-stat">Min increment: <strong id="minIncrement">$1</strong></div>
              </div>
            </div>
          </div>

          <div class="sidebar">
            <div class="bid-form" id="bidForm">
              <h3>Place a Bid</h3>
              <input class="name-input" type="text" id="bidderName" placeholder="Your name" />
              <div class="min-bid-hint" id="minBidHint">Minimum bid: $0</div>
              <input class="name-input" type="number" id="bidAmount" placeholder="Enter bid amount" style="font-size:18px;font-weight:700;" />
              <button class="btn-bid" id="bidBtn" onclick="placeBid()">Place Bid</button>
            </div>

            <div class="bid-history">
              <h3>Bid History</h3>
              <div id="bidList"><div class="no-bids">No bids yet. Be the first!</div></div>
            </div>
          </div>
        </div>
      </div>

      <div class="toast-container" id="toasts"></div>

      <script>
        var AUCTION_ID = #{Jason.encode!(id)};
        var auction = null;
        var ws = null;
        var timeRemaining = 0;
        var timerInterval = null;

        function showToast(message, type) {
          var container = document.getElementById('toasts');
          var toast = document.createElement('div');
          toast.className = 'toast ' + (type || '');
          toast.textContent = message;
          container.appendChild(toast);
          setTimeout(function() { toast.remove(); }, 3000);
        }

        function renderBidEntry(b) {
          var entry = document.createElement('div');
          entry.className = 'bid-entry';
          var bidder = document.createElement('span');
          bidder.className = 'bidder';
          bidder.textContent = b.bidder;
          var amount = document.createElement('span');
          amount.className = 'amount';
          amount.textContent = '$' + b.amount;
          entry.appendChild(bidder);
          entry.appendChild(amount);
          return entry;
        }

        function renderBids(bids) {
          var list = document.getElementById('bidList');
          list.textContent = '';
          if (!bids || bids.length === 0) {
            var noBids = document.createElement('div');
            noBids.className = 'no-bids';
            noBids.textContent = 'No bids yet. Be the first!';
            list.appendChild(noBids);
            return;
          }
          var reversed = bids.slice().reverse();
          reversed.forEach(function(b) {
            list.appendChild(renderBidEntry(b));
          });
        }

        function updateUI(a) {
          auction = a;
          document.getElementById('auctionTitle').textContent = a.title;
          document.getElementById('auctionDesc').textContent = a.description || '';
          document.getElementById('currentPrice').textContent = '$' + a.current_price;
          document.getElementById('bidCount').textContent = a.bid_count || 0;
          document.getElementById('leadingBidder').textContent = a.highest_bidder || '---';
          document.getElementById('minIncrement').textContent = '$' + (a.min_increment || 1);

          var minBid = a.current_price + (a.min_increment || 1);
          document.getElementById('minBidHint').textContent = 'Minimum bid: $' + minBid;
          document.getElementById('bidAmount').placeholder = '$' + minBid;
          document.getElementById('bidAmount').min = minBid;

          if (a.status !== 'active') {
            document.getElementById('statusBadge').className = 'status-badge ended';
            document.getElementById('statusBadge').textContent = 'ENDED';
            document.getElementById('currentPrice').classList.add('ended');
            document.getElementById('bidBtn').disabled = true;
            document.getElementById('bidBtn').textContent = 'Auction Ended';
            document.getElementById('timer').textContent = 'ENDED';
            document.getElementById('timer').classList.remove('urgent');

            if (a.highest_bidder) {
              var banner = document.getElementById('winnerBanner');
              banner.style.display = 'block';
              banner.textContent = 'Winner: ' + a.highest_bidder + ' at $' + a.current_price;
            }
          } else {
            timeRemaining = a.time_remaining;
            updateTimer();
          }

          renderBids(a.bids || []);
        }

        function updateTimer() {
          var el = document.getElementById('timer');
          if (timeRemaining <= 0) {
            el.textContent = 'ENDING...';
            el.classList.add('urgent');
            return;
          }
          var m = Math.floor(timeRemaining / 60);
          var s = timeRemaining % 60;
          el.textContent = m + ':' + String(s).padStart(2, '0');
          if (timeRemaining < 60) { el.classList.add('urgent'); } else { el.classList.remove('urgent'); }
        }

        function startLocalTimer() {
          if (timerInterval) clearInterval(timerInterval);
          timerInterval = setInterval(function() {
            if (timeRemaining > 0) {
              timeRemaining--;
              updateTimer();
            }
          }, 1000);
        }

        function connectWS() {
          var name = document.getElementById('bidderName').value || 'Guest';
          var proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
          ws = new WebSocket(proto + '//' + location.host + '/ws/auction/' + AUCTION_ID + '?name=' + encodeURIComponent(name));

          ws.onopen = function() { console.log('WebSocket connected'); };

          ws.onmessage = function(event) {
            var msg = JSON.parse(event.data);
            switch (msg.type) {
              case 'new_bid':
                if (auction) {
                  auction.current_price = msg.amount;
                  auction.highest_bidder = msg.bidder;
                  auction.bid_count = (auction.bid_count || 0) + 1;
                  if (!auction.bids) auction.bids = [];
                  auction.bids.push({ bidder: msg.bidder, amount: msg.amount });
                  timeRemaining = msg.time_remaining;
                  updateUI(auction);
                }
                showToast(msg.bidder + ' bid $' + msg.amount, 'bid');
                break;
              case 'outbid':
                showToast('Outbid by ' + msg.by + ' at $' + msg.amount, 'outbid');
                break;
              case 'countdown':
                timeRemaining = msg.seconds;
                updateTimer();
                break;
              case 'auction_ended':
                showToast('Auction ended! Winner: ' + (msg.winner || 'No winner') + ' at $' + msg.final_price, 'ended');
                if (auction) {
                  auction.status = 'ended';
                  auction.highest_bidder = msg.winner;
                  auction.current_price = msg.final_price;
                  updateUI(auction);
                }
                break;
              case 'bid_history':
                if (auction && msg.bids) {
                  auction.bids = msg.bids;
                  renderBids(msg.bids);
                }
                break;
              case 'error':
                showToast(msg.message, 'outbid');
                break;
            }
          };

          ws.onclose = function() {
            console.log('WebSocket disconnected, reconnecting in 2s...');
            setTimeout(connectWS, 2000);
          };
        }

        function placeBid() {
          var amount = parseFloat(document.getElementById('bidAmount').value);
          if (!amount || isNaN(amount)) return;

          if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'bid', amount: amount }));
            document.getElementById('bidAmount').value = '';
          } else {
            var name = document.getElementById('bidderName').value || 'Guest';
            fetch('/api/auctions/' + AUCTION_ID + '/bid', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ bidder: name, amount: amount })
            })
            .then(function(r) { return r.json(); })
            .then(function(data) {
              if (data.error) {
                showToast(data.error, 'outbid');
              } else {
                document.getElementById('bidAmount').value = '';
                loadAuction();
              }
            });
          }
        }

        document.getElementById('bidAmount').addEventListener('keypress', function(e) {
          if (e.key === 'Enter') placeBid();
        });

        function loadAuction() {
          fetch('/api/auctions/' + AUCTION_ID)
            .then(function(r) { return r.json(); })
            .then(function(data) {
              if (data.auction) {
                updateUI(data.auction);
                document.title = data.auction.title + ' - Hibana Auctions';
              }
            })
            .catch(function() {});
        }

        var guestNames = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Heidi'];
        document.getElementById('bidderName').value = guestNames[Math.floor(Math.random() * guestNames.length)];

        loadAuction();
        startLocalTimer();
        setTimeout(connectWS, 500);
      </script>
    </body>
    </html>
    """)
  end
end
