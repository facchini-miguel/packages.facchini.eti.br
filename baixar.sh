#!/bin/bash
# Downloads into pacotes/ the .deb and .rpm of every GitHub release of each project in
# PROJETOS, each checked against the SHA256SUMS of its own release. Releases without packages
# (Kaladrius before 0.54.0) are skipped. Needs gh (GH_TOKEN in CI).
set -euo pipefail
cd "$(dirname "$0")"

PROJETOS=(facchini-miguel/kaladrius)

mkdir -p pacotes
for projeto in "${PROJETOS[@]}"; do
  gh release list -R "$projeto" --limit 1000 --exclude-drafts --exclude-pre-releases \
    --json tagName --jq '.[].tagName' >pacotes/.tags
  while read -r tag; do
    ativos=$(gh release view "$tag" -R "$projeto" --json assets --jq '.assets[].name')
    grep -qE '\.(deb|rpm)$' <<<"$ativos" || continue
    grep -qx SHA256SUMS <<<"$ativos" || { echo "$projeto $tag: pacotes sem SHA256SUMS" >&2; exit 1; }
    tmp=$(mktemp -d)
    gh release download "$tag" -R "$projeto" -D "$tmp" -p '*.deb' -p '*.rpm' -p SHA256SUMS
    (cd "$tmp" && sha256sum --quiet --ignore-missing -c SHA256SUMS)
    mv "$tmp"/*.deb "$tmp"/*.rpm pacotes/
    rm -rf "$tmp"
    echo "$projeto $tag"
  done <pacotes/.tags
  rm -f pacotes/.tags
done
ls pacotes/*.deb pacotes/*.rpm >/dev/null  # at least one of each
