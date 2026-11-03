#!/bin/bash
# Downloads into pacotes/<name>/ the .deb and .rpm of every GitHub release of each project in
# PROJETOS (<name>: the repository's name, which is also its folder on the site), each checked
# against the SHA256SUMS of its own release. Releases without packages (Kaladrius before
# 0.54.0) are skipped. Needs gh (GH_TOKEN in CI).
set -euo pipefail
cd "$(dirname "$0")"

PROJETOS=(facchini-miguel/kaladrius)

rm -rf pacotes
for projeto in "${PROJETOS[@]}"; do
  destino=pacotes/${projeto#*/}
  mkdir -p "$destino"
  tags=$(gh release list -R "$projeto" --limit 1000 --exclude-drafts --exclude-pre-releases \
    --json tagName --jq '.[].tagName')
  for tag in $tags; do
    ativos=$(gh release view "$tag" -R "$projeto" --json assets --jq '.assets[].name')
    grep -qE '\.(deb|rpm)$' <<<"$ativos" || continue
    grep -qx SHA256SUMS <<<"$ativos" || { echo "$projeto $tag: pacotes sem SHA256SUMS" >&2; exit 1; }
    tmp=$(mktemp -d)
    gh release download "$tag" -R "$projeto" -D "$tmp" -p '*.deb' -p '*.rpm' -p SHA256SUMS
    (cd "$tmp" && sha256sum --quiet --ignore-missing -c SHA256SUMS)
    mv "$tmp"/*.deb "$tmp"/*.rpm "$destino/"
    rm -rf "$tmp"
    echo "$projeto $tag"
  done
  # At least one of each.
  ls "$destino"/*.deb "$destino"/*.rpm >/dev/null
done
