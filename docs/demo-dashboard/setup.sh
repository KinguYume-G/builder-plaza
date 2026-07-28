#!/usr/bin/env bash
# Derives the Grafana datasource credentials from the repo-root .env and starts
# the dashboard. Writes .env.local, which .gitignore already covers via `.env.*`
# — the database password must never reach the repository.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/../.."

python3 - "$root/.env" > "$here/.env.local" <<'PY'
import sys, urllib.parse

url = None
for line in open(sys.argv[1]):
    if line.startswith("DATABASE_URL="):
        url = line.split("=", 1)[1].strip()
        break
if not url:
    sys.exit("DATABASE_URL not found in .env")

u = urllib.parse.urlparse(url.replace("postgresql+psycopg://", "//"))
print(f"PGHOST={u.hostname}:{u.port or 5432}")
print(f"PGDATABASE={(u.path or '').lstrip('/')}")
print(f"PGUSER={urllib.parse.unquote(u.username or '')}")
print(f"PGPASSWORD={urllib.parse.unquote(u.password or '')}")
PY

chmod 600 "$here/.env.local"
echo "wrote .env.local (gitignored)"

cd "$here"
docker compose up -d
echo
echo "Dashboard:  http://localhost:3000"
