#!/usr/bin/env bash
set -euo pipefail

if [ -f /etc/hostname ]; then
  _raw=$(tr -d '[:space:]' </etc/hostname)
else
  _raw=$(hostname 2>/dev/null || echo "unknown")
fi
case "$_raw" in
galactica*) HOST_NAME="galactica" ;;
matic*) HOST_NAME="matic" ;;
kyber*) HOST_NAME="kyber" ;;
*) HOST_NAME="$_raw" ;;
esac

MEMPALACE_BIN="$HOME/.local/share/uv/tools/mempalace"
MEMPALACE_PYTHON="$MEMPALACE_BIN/bin/python"
CONFIG_FILE="$HOME/.mempalace/config.json"
WIKI_SYNC="$HOME/.mempalace/wiki-sync"

[ -x "$MEMPALACE_PYTHON" ] || {
  echo "mempalace not installed, skipping"
  exit 0
}
[ -f "$CONFIG_FILE" ] || {
  echo "no mempalace config, skipping"
  exit 0
}

PALACE_PATH=$("$MEMPALACE_PYTHON" -c "import json; print(json.load(open('$CONFIG_FILE'))['palace_path'])")
MEMPALACE_SITE=$("$MEMPALACE_PYTHON" -c 'import sysconfig; print(sysconfig.get_path("purelib"))')

if [ -d "$WIKI_SYNC/.git" ]; then
  git -C "$WIKI_SYNC" fetch origin main
  git -C "$WIKI_SYNC" checkout -f main 2>/dev/null || git -C "$WIKI_SYNC" checkout -f -b main origin/main
  git -C "$WIKI_SYNC" merge --ff-only origin/main || git -C "$WIKI_SYNC" reset --mixed origin/main
else
  mkdir -p "$HOME/.mempalace"
  git clone "https://github.com/shunkakinoki/wiki.git" "$WIKI_SYNC"
fi

"$MEMPALACE_PYTHON" -c "
import sys
sys.path.insert(0, '$MEMPALACE_SITE')
from mempalace.exporter import export_palace
export_palace(palace_path='$PALACE_PATH', output_dir='$WIKI_SYNC/palace/$HOST_NAME')
"

cd "$WIKI_SYNC"
git add "palace/$HOST_NAME/"
if git diff --cached --quiet; then
  echo "No palace changes for $HOST_NAME, skipping"
  exit 0
fi
git commit -m "chore: update mempalace palace export ($HOST_NAME)"
git merge --ff-only origin/main 2>/dev/null || true
git push origin main
