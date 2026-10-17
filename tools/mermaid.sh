#!/bin/sh
# Каждая mermaid-схема мануала собирается: mmdc рисует все блоки ```mermaid файла в SVG (во временный каталог).
# Запуск — сервис mermaid в compose.yaml (make test). Ошибка в схеме — выход 1 и имя файла.
set -u
out=$(mktemp -d)
fail=0
n=0
for md in $(find /man -name '*.md' | sort); do
  grep -q '^```mermaid' "$md" || continue
  n=$((n + $(grep -c '^```mermaid' "$md")))
  if ! /home/mermaidcli/node_modules/.bin/mmdc -p /puppeteer-config.json -q -i "$md" -o "$out/x.md" >"$out/log" 2>&1; then
    echo "FAIL: схема не собирается: ${md#/man/}"
    grep -iE 'error|parse' "$out/log" | head -5
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "man: схемы собираются ($n)"
exit "$fail"
