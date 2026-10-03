#!/bin/sh
# Клонировать недостающие подрепозитории и обновить имеющиеся. Только git: идёт на VM, ключи в контейнер не попадают.
# Незакоммиченное и чужие ветки не трогаются: обновление — только перемоткой вперёд.
set -eu
cd "$(dirname "$0")/.."
mkdir -p repos
sh tools/repos.sh | while read -r name url version; do
  dir=repos/$name
  if [ ! -d "$dir/.git" ]; then
    git clone -q "$url" "$dir" && echo "$name: склонирован"
    continue
  fi
  git -C "$dir" fetch -q --prune --tags origin
  branch=$(git -C "$dir" symbolic-ref -q --short HEAD || echo "")
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "$name: есть незакоммиченное — не обновлял"
  elif [ "$branch" = "$version" ] && git -C "$dir" rev-parse -q --verify "origin/$version" >/dev/null; then
    git -C "$dir" merge -q --ff-only "origin/$version" && echo "$name: $version обновлена"
  else
    echo "$name: на ветке ${branch:-(без ветки)}, обновлены только ссылки с сервера"
  fi
done
