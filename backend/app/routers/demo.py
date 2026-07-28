"""Live database counters for the recorded app demo.

Exists so the demo video can prove that tapping through the app really moves
rows in the database, without cutting to a SQL client and clicking refresh: the
dashboard at ``/demo/live`` polls ``/demo/db-stats`` and flashes a counter the
moment it changes.

Deliberately narrow, because this is served publicly next to the real API:

* **Counts only.** Every response is ``{table: row_count}``. No row contents, no
  user data, nothing personally identifying ever leaves this router.
* **Fixed table list.** ``_TABLES`` is a module constant that is interpolated
  into the SQL; nothing from the request reaches the query, so there is no
  injection surface.
* **Read-only.** Only ``SELECT count(*)`` is issued.
"""

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.session import get_db

router = APIRouter(prefix="/demo", tags=["demo"])

# The 11 business tables, in the order the demo narrative touches them, so the
# dashboard reads top-to-bottom as the video progresses.
_TABLES = [
    "users",
    "project_cards",
    "intents",
    "growth_posts",
    "matches",
    "collab_requests",
    "conversations",
    "messages",
    "peer_reviews",
    "role_postings",
    "skill_embeddings",
]


@router.get("/db-stats")
def db_stats(db: Session = Depends(get_db)) -> dict[str, int]:
    """Row count per business table. Counts only — never row contents."""
    # One round trip: a single SELECT with a subquery per table beats 11 queries
    # when the dashboard polls this every second.
    columns = ", ".join(f'(select count(*) from {t}) as "{t}"' for t in _TABLES)
    row = db.execute(text(f"select {columns}")).mappings().one()
    return {t: int(row[t]) for t in _TABLES}


_PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Builder Plaza — live database</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 28px 24px;
    background: #12100e; color: #f7f3ec;
    font: 16px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
  }
  h1 { margin: 0 0 4px; font-size: 20px; letter-spacing: .08em; text-transform: uppercase; }
  .sub { margin: 0 0 22px; color: #8b8377; font-size: 12px; letter-spacing: .05em; }
  .grid { display: grid; gap: 10px; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); }
  .cell {
    display: flex; align-items: baseline; justify-content: space-between; gap: 12px;
    padding: 14px 16px; border: 2px solid #2c2823; border-radius: 10px;
    background: #191612; transition: background .25s, border-color .25s;
    /* Grid items default to min-width:auto, so a long table name like
       skill_embeddings blows the column past its 1fr share and pushes the whole
       row off-screen. This is the fix. */
    min-width: 0;
  }
  .name {
    color: #a49b8d; font-size: 13px; letter-spacing: .04em;
    min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
  }
  .val { font-size: 30px; font-weight: 700; font-variant-numeric: tabular-nums; }
  .delta {
    margin-left: 8px; font-size: 13px; font-weight: 700; color: #7ddb8f;
    opacity: 0; transition: opacity .3s;
  }
  .cell.hit { background: #1d3324; border-color: #4ea865; }
  .cell.hit .delta { opacity: 1; }
  .foot { margin-top: 22px; color: #6f6759; font-size: 12px; }
  .dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%;
         background: #4ea865; margin-right: 7px; vertical-align: middle; }
  .dot.stale { background: #b4543a; }
</style>
</head>
<body>
  <h1>Builder Plaza — live database</h1>
  <p class="sub">Row counts, polled once per second. A counter flashes when it changes.</p>
  <div class="grid" id="grid"></div>
  <p class="foot"><span class="dot" id="dot"></span><span id="status">connecting…</span></p>
<script>
  const grid = document.getElementById('grid');
  const dot = document.getElementById('dot');
  const status = document.getElementById('status');
  const cells = {};
  let previous = null;

  function cellFor(name) {
    if (cells[name]) return cells[name];
    const el = document.createElement('div');
    el.className = 'cell';
    el.innerHTML = `<span class="name">${name}</span>` +
                   `<span><span class="val">–</span><span class="delta"></span></span>`;
    grid.appendChild(el);
    cells[name] = { el, val: el.querySelector('.val'), delta: el.querySelector('.delta') };
    return cells[name];
  }

  async function tick() {
    try {
      const res = await fetch('db-stats', { cache: 'no-store' });
      if (!res.ok) throw new Error('HTTP ' + res.status);
      const data = await res.json();
      for (const [name, count] of Object.entries(data)) {
        const cell = cellFor(name);
        cell.val.textContent = count;
        if (previous && previous[name] !== undefined && previous[name] !== count) {
          const diff = count - previous[name];
          cell.delta.textContent = (diff > 0 ? '+' : '') + diff;
          cell.el.classList.add('hit');
          // Hold the highlight long enough to be unmissable on video.
          clearTimeout(cell.timer);
          cell.timer = setTimeout(() => cell.el.classList.remove('hit'), 4000);
        }
      }
      previous = data;
      dot.classList.remove('stale');
      status.textContent = 'live · updated ' + new Date().toLocaleTimeString();
    } catch (err) {
      dot.classList.add('stale');
      status.textContent = 'reconnecting — ' + err.message;
    }
  }

  tick();
  setInterval(tick, 1000);
</script>
</body>
</html>
"""


@router.get("/live", response_class=HTMLResponse)
def live_dashboard() -> HTMLResponse:
    """Self-contained dashboard page for screen-sharing during the demo."""
    return HTMLResponse(_PAGE)
