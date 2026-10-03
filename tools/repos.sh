#!/bin/sh
# Подрепозитории из repos.yaml одной строкой на каждый: <name> <url> <version>.
# Только sh и awk — работает и на VM (для git с ключами), и в контейнере; make test сверяет вывод с yq.
cd "$(dirname "$0")/.."
awk '
  function flush() { if (name != "") print name, url, version; name = url = version = "" }
  /^[[:space:]]*-[[:space:]]*name:/ { flush(); sub(/^[^:]*:[[:space:]]*/, ""); name = $0; next }
  /^[[:space:]]+url:/              { sub(/^[^:]*:[[:space:]]*/, ""); url = $0; next }
  /^[[:space:]]+version:/          { sub(/^[^:]*:[[:space:]]*/, ""); version = $0; next }
  END { flush() }
' repos.yaml
