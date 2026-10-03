#!/bin/sh
# Проверка orb-bundam: обязательные файлы, repos.yaml, ссылки, секреты.
set -eu
cd "$(dirname "$0")/.."
fail=0
err() { echo "FAIL: $*"; fail=1; }

for f in README.md STATUS.md GOALS.md ROADMAP.md CHANGELOG.md repos.yaml decisions/README.md think/README.md; do
  [ -f "$f" ] || err "нет файла $f"
done

# repos.yaml: поля, допустимые значения, уникальные имена.
n=$(yq '.repos | length' repos.yaml)
[ "$n" -gt 0 ] || err "repos.yaml: пустой список"
bad=$(yq '.repos[] | select((.name|type) != "!!str" or (.url|type) != "!!str" or (.role|type) != "!!str"
      or (.version|type) != "!!str" or (.strict|type) != "!!bool"
      or ((.status == "active" or .status == "source" or .status == "archive") | not)) | .name' repos.yaml)
[ -z "$bad" ] || err "repos.yaml: неполные или неверные записи: $bad"
dups=$(yq '.repos[].name' repos.yaml | sort | uniq -d)
[ -z "$dups" ] || err "repos.yaml: повторяются имена: $dups"
# Разбор на VM (awk) должен совпадать с настоящим разбором YAML.
[ "$(sh tools/repos.sh)" = "$(yq '.repos[] | .name + " " + .url + " " + .version' repos.yaml)" ] \
  || err "tools/repos.sh читает repos.yaml не так, как yq — упрости формат или поправь разбор"

# Относительные ссылки.
for md in $(find . -name '*.md' -not -path './.git/*' -not -path './repos/*'); do
  dir=$(dirname "$md")
  grep -o '](\([^)#]*\)[^)]*)' "$md" | sed 's/^](\([^)#]*\).*/\1/' | while read -r link; do
    case "$link" in ''|http://*|https://*|mailto:*) continue ;; esac
    [ -e "$dir/$link" ] || echo "FAIL: $md → $link"
  done
done > /tmp/links
[ ! -s /tmp/links ] || { cat /tmp/links; fail=1; }

# Репозиторий открытый: секретов быть не должно ни в файлах, ни в истории.
mkdir -p /tmp/tree && find . -mindepth 1 -maxdepth 1 ! -name repos ! -name .git -exec cp -r {} /tmp/tree/ \;
sh tools/secrets.sh /tmp/tree || err "секреты в файлах"
git log -p --all 2>/dev/null | sh tools/secrets.sh --stdin || err "секрет в истории"

[ "$fail" -eq 0 ] && echo "orb-bundam: ok"
exit "$fail"
