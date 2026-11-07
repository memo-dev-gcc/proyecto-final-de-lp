#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd -- "$(dirname -- "$0")/.."
if ! command -v mix >/dev/null 2>&1; then
  echo "Necesitas Elixir. En macOS: brew install elixir"
  echo "O consulta https://elixir-lang.org/install.html"
  exit 1
fi
if ! mix hex.info >/dev/null 2>&1; then mix local.hex --force; fi
mix deps.get
printf '\nArena de acero: http://localhost:%s\n' "${PORT:-4000}"
printf 'Para jugar por LAN, abre la IP local de esta computadora con el mismo puerto.\n'
printf 'Cada navegador debe elegir un vehículo distinto en la misma sala.\n\n'
exec mix run --no-halt
