#!/bin/sh
# Состояние подрепозиториев: ветка, впереди/позади origin, незакоммиченные файлы. Только git, без сети.
cd "$(dirname "$0")/.."
printf '%-22s %-28s %-14s %s\n' РЕПОЗИТОРИЙ ВЕТКА "ВПЕРЕДИ/ПОЗАДИ" НЕЗАКОММИЧЕНО
sh tools/repos.sh | while read -r name url version; do
  dir=repos/$name
  if [ ! -d "$dir/.git" ]; then printf '%-22s %s\n' "$name" "нет клона — make sync"; continue; fi
  branch=$(git -C "$dir" symbolic-ref -q --short HEAD || echo "-")
  ab=$(git -C "$dir" rev-list --left-right --count "HEAD...@{upstream}" 2>/dev/null | awk '{print "+"$1"/-"$2}')
  dirty=$(git -C "$dir" status --porcelain | wc -l | tr -d ' ')
  printf '%-22s %-28s %-14s %s\n' "$name" "$branch" "${ab:-нет upstream}" "$dirty"
done
