#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="paperclip"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

IMAGE="${PAPERCLIP_IMAGE:-ghcr.io/paperclipai/paperclip:latest}"
DATA_DIR="${PAPERCLIP_DATA_DIR:-${HOME}/.paperclip}"
PUBLIC_URL="${PAPERCLIP_PUBLIC_URL:-https://paperclip.shunkakinoki.com}"
CLIPROXY_URL="${PAPERCLIP_CLIPROXY_URL:-http://127.0.0.1:8317}"
GENERATED_ENV="${DATA_DIR}/generated.env"

umask 077
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

# Paperclip refuses to boot without these. Generate them once and reuse them on
# every restart; values in ~/dotfiles/.env take precedence.
if [ ! -f "$GENERATED_ENV" ]; then
  {
    printf 'BETTER_AUTH_SECRET=%s\n' "$(@openssl@ rand -hex 32)"
    printf 'PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=%s\n' "$(@openssl@ rand -hex 32)"
  } >"$GENERATED_ENV"
fi
while IFS='=' read -r key value; do
  [ -n "$key" ] || continue
  if [ -z "${!key:-}" ]; then
    export "$key=$value"
  fi
done <"$GENERATED_ENV"

if [ -z "${CLIPROXY_API_KEY:-}" ]; then
  echo "CLIPROXY_API_KEY is not set in ${ENV_FILE}" >&2
  exit 1
fi

ensure_container_removed() {
  @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do
    if ! @docker@ inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  done
  ! @docker@ inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

child_pid=""
trap '
  @docker@ stop --time 80 "$CONTAINER_NAME" >/dev/null 2>&1 || @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  if [ -n "$child_pid" ]; then
    wait "$child_pid" 2>/dev/null || true
  fi
' TERM INT

if @docker@ info >/dev/null 2>&1; then
  echo "Pulling Paperclip image..."
  @docker@ pull "$IMAGE" || true
else
  echo "Docker is not accessible" >&2
  exit 1
fi

if ! ensure_container_removed; then
  echo "Failed to remove stale Paperclip container" >&2
  exit 1
fi

# Agents run the image's bundled Claude Code and Codex CLIs. Route both through
# the host's CLIProxyAPI, the same way the claude-cliproxy and codex-cliproxy
# harnesses do, so no provider credential enters the container.
export ANTHROPIC_AUTH_TOKEN="$CLIPROXY_API_KEY"
export OPENAI_API_KEY="$CLIPROXY_API_KEY"
export BETTER_AUTH_SECRET PAPERCLIP_TOOL_ACTION_SIGNING_SECRET

docker_args=(
  run
  --rm
  --name "$CONTAINER_NAME"
  # The image starts as root only to remap its node user to these IDs, then
  # drops privileges, so the bind-mounted home stays owned by the service user.
  -e "USER_UID=$(id -u)"
  -e "USER_GID=$(id -g)"
  # Host networking reaches CLIProxyAPI on loopback. The WAN firewall keeps
  # port 3100 off the public internet.
  --network host
  --pids-limit 2048
  -v "$DATA_DIR:/paperclip"
  -e "HOST=0.0.0.0"
  -e "PORT=3100"
  -e "PAPERCLIP_DEPLOYMENT_MODE=authenticated"
  -e "PAPERCLIP_DEPLOYMENT_EXPOSURE=private"
  -e "PAPERCLIP_PUBLIC_URL=${PUBLIC_URL}"
  -e "PAPERCLIP_AUTH_DISABLE_SIGN_UP=true"
  -e BETTER_AUTH_SECRET
  -e PAPERCLIP_TOOL_ACTION_SIGNING_SECRET
  -e "ANTHROPIC_BASE_URL=${CLIPROXY_URL}"
  -e ANTHROPIC_AUTH_TOKEN
  -e "ANTHROPIC_API_KEY="
  -e "OPENAI_BASE_URL=${CLIPROXY_URL}/v1"
  -e OPENAI_API_KEY
)

@docker@ "${docker_args[@]}" "$IMAGE" &
child_pid=$!
wait "$child_pid"
