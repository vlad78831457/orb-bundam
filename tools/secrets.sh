#!/bin/sh
# Поиск секретов. secrets.sh <каталог> — файлы и строки; secrets.sh --stdin — строки из потока (история git).
# Выход 1, если найдено. Значения не печатаются — только где.
PATTERN='(sk-[A-Za-z0-9_-]{20,}|AQVN[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

if [ "${1:-}" = "--stdin" ]; then
  if grep -qE "$PATTERN"; then echo "секрет в истории"; exit 1; fi
  exit 0
fi

dir=${1:?каталог}
found=0
bad=$(find "$dir" -not -path '*/.git/*' \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name 'id_rsa*' -o -name 'id_ed25519*' -o -name 'id_ecdsa*' \) ! -name '.env.example')
if [ -n "$bad" ]; then echo "файлы с секретами:"; echo "$bad" | sed 's/^/  /'; found=1; fi
hits=$(find "$dir" -type f -not -path '*/.git/*' -not -name secrets.sh -print0 | xargs -0 -r grep -lE "$PATTERN")
if [ -n "$hits" ]; then echo "строки, похожие на ключи, в файлах:"; echo "$hits" | sed 's/^/  /'; found=1; fi
exit $found
