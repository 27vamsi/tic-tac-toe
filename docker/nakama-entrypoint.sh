#!/bin/sh
set -eu

normalize_origin() {
  origin=$(echo "$1" | tr -d ' ')
  [ -z "$origin" ] && return
  case "$origin" in
    http://*|https://*) printf '%s' "$origin" ;;
    *) printf 'https://%s' "$origin" ;;
  esac
}

build_database_address() {
  if [ -n "${NAKAMA_DATABASE_ADDRESS:-}" ]; then
    printf '%s' "$NAKAMA_DATABASE_ADDRESS"
    return
  fi

  user="${NAKAMA_DATABASE_USER:?NAKAMA_DATABASE_USER is required}"
  password="${NAKAMA_DATABASE_PASSWORD:?NAKAMA_DATABASE_PASSWORD is required}"
  host="${NAKAMA_DATABASE_HOST:?NAKAMA_DATABASE_HOST is required}"
  port="${NAKAMA_DATABASE_PORT:-5432}"
  db="${NAKAMA_DATABASE_NAME:?NAKAMA_DATABASE_NAME is required}"
  sslmode="${NAKAMA_DATABASE_SSLMODE:-disable}"

  address="${user}:${password}@${host}:${port}/${db}"
  if [ "$sslmode" != "disable" ] && [ -n "$sslmode" ]; then
    address="${address}?sslmode=${sslmode}"
  fi
  printf '%s' "$address"
}

DB_ADDRESS=$(build_database_address)
ENCRYPTION_KEY="${NAKAMA_SESSION_ENCRYPTION_KEY:?NAKAMA_SESSION_ENCRYPTION_KEY is required}"
SERVER_KEY="${NAKAMA_SERVER_KEY:-defaultkey}"
LOGGER_LEVEL="${NAKAMA_LOGGER_LEVEL:-INFO}"
TOKEN_EXPIRY="${NAKAMA_SESSION_TOKEN_EXPIRY_SEC:-7200}"
MAX_EMPTY="${NAKAMA_MATCH_MAX_EMPTY_SEC:-60}"

set -- /nakama/nakama \
  --name nakama \
  --database.address "$DB_ADDRESS" \
  --logger.level "$LOGGER_LEVEL" \
  --session.token_expiry_sec "$TOKEN_EXPIRY" \
  --session.encryption_key "$ENCRYPTION_KEY" \
  --match.max_empty_sec "$MAX_EMPTY" \
  --socket.server_key "$SERVER_KEY"

if [ -n "${NAKAMA_SOCKET_ALLOWED_ORIGINS:-}" ]; then
  OLD_IFS=$IFS
  IFS=,
  for raw in $NAKAMA_SOCKET_ALLOWED_ORIGINS; do
    origin=$(normalize_origin "$raw")
    if [ -n "$origin" ]; then
      set -- "$@" --socket.allowed_origins "$origin"
    fi
  done
  IFS=$OLD_IFS
fi

echo "Running Nakama migrations..."
/nakama/nakama migrate up --database.address "$DB_ADDRESS"

echo "Starting Nakama..."
exec "$@"
