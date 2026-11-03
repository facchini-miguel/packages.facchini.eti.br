#!/bin/bash
# Builds _site/ from site/ and the packages in pacotes/<name>/ (baixar.sh). For each software:
#   /<name>/deb  an apt repository (suite "stable", component "main", amd64) and <name>.sources,
#                the apt source with the key inside it (deb822)
#   /<name>/rpm  a dnf/zypper repository, every package signed, and <name>.repo
# plus /versoes.txt, the packages published (the hourly run compares it to skip a deploy), and
# a plain listing (index.html) in every folder, the home page included, like
# packages.microsoft.com: how to install each software is in its own documentation.
# Everything is signed with the private key in GPG_CHAVE_PRIVADA, which must be the one in
# site/facchini.asc (the key clients trust). The key lives only in a temporary GNUPGHOME.
set -euo pipefail
cd "$(dirname "$0")"
: "${GPG_CHAVE_PRIVADA:?a chave privada (secret do repositório)}"
SITE=https://packages.facchini.eti.br

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT
gpg --batch --quiet --import <<<"$GPG_CHAVE_PRIVADA"
CHAVE=$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr:/ {print $10; exit}')
PUBLICA=$(gpg --batch --with-colons --show-keys site/facchini.asc | awk -F: '/^fpr:/ {print $10; exit}')
if [ "$CHAVE" != "$PUBLICA" ]; then
  echo "A chave do secret ($CHAVE) não é a de site/facchini.asc ($PUBLICA)." >&2
  exit 1
fi
assinar() { gpg --batch --yes --local-user "$CHAVE" "$@"; }

# The apt repository of one software.
apt_repositorio() {
  local nome=$1 deb=_site/$1/deb
  mkdir -p "$deb/pool/main" "$deb/dists/stable/main/binary-amd64"
  cp "pacotes/$nome"/*.deb "$deb/pool/main/"
  (
    cd "$deb"
    apt-ftparchive packages pool/main >dists/stable/main/binary-amd64/Packages
    gzip -9nk dists/stable/main/binary-amd64/Packages
    cd dists/stable
    apt-ftparchive \
      -o APT::FTPArchive::Release::Origin=packages.facchini.eti.br \
      -o APT::FTPArchive::Release::Label="$nome" \
      -o APT::FTPArchive::Release::Suite=stable \
      -o APT::FTPArchive::Release::Codename=stable \
      -o APT::FTPArchive::Release::Architectures=amd64 \
      -o APT::FTPArchive::Release::Components=main \
      release . >../Release.tmp
    mv ../Release.tmp Release
  )
  assinar --clearsign -o "$deb/dists/stable/InRelease" "$deb/dists/stable/Release"
  assinar --armor --detach-sign -o "$deb/dists/stable/Release.gpg" "$deb/dists/stable/Release"
  # deb822, with the key in Signed-By (apt 2.3.10+: Debian 12+, Ubuntu 22.04+): a single
  # file to download, the same one the package itself writes (decision 142).
  {
    echo "# $nome, from $SITE"
    echo "Types: deb"
    echo "URIs: $SITE/$nome/deb"
    echo "Suites: stable"
    echo "Components: main"
    echo "Architectures: amd64"
    echo "Signed-By:"
    sed -e 's/^$/./' -e 's/^/ /' site/facchini.asc
  } >"$deb/$nome.sources"
}

# The dnf / zypper repository of one software.
rpm_repositorio() {
  local nome=$1 rpm=_site/$1/rpm
  mkdir -p "$rpm/pacotes"
  cp "pacotes/$nome"/*.rpm "$rpm/pacotes/"
  # Ubuntu's rpm looks for gpg under another name: the path is given.
  rpmsign --define "__gpg $(command -v gpg)" --define "_gpg_name $CHAVE" \
    --define "_gpg_path $GNUPGHOME" --addsign "$rpm"/pacotes/*.rpm >/dev/null
  createrepo_c --quiet "$rpm"
  assinar --armor --detach-sign -o "$rpm/repodata/repomd.xml.asc" "$rpm/repodata/repomd.xml"
  # autorefresh: zypper checks the repository on every update, as dnf does.
  cat >"$rpm/$nome.repo" <<REPO
[$nome]
name=$nome ($SITE)
baseurl=$SITE/$nome/rpm
type=rpm-md
enabled=1
autorefresh=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$SITE/facchini.asc
REPO
}

# A plain listing of a folder, like a web server's (GitHub Pages has none).
listagem() {
  local pasta=$1 caminho=${1#_site} item tmp acima='<a href="../">../</a><br>\n'
  tmp=$(mktemp)
  {
    printf '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
    printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    printf '<title>packages.facchini.eti.br%s/</title>\n' "$caminho"
    printf '<style>body{font:15px/1.7 ui-monospace,monospace;margin:32px 16px}a{color:#0969da}'
    printf '@media(prefers-color-scheme:dark){body{background:#0d1117;color:#e6edf3}a{color:#4493f8}}</style>\n'
    [ -n "$caminho" ] || acima=""
    printf '</head>\n<body>\n<h1>packages.facchini.eti.br%s/</h1>\n%b' "$caminho" "$acima"
    for item in "$pasta"/*/; do
      [ -d "$item" ] && printf '<a href="%s/">%s/</a><br>\n' "$(basename "$item")" "$(basename "$item")"
    done
    for item in "$pasta"/*; do
      [ -f "$item" ] && printf '<a href="%s">%s</a><br>\n' "$(basename "$item")" "$(basename "$item")"
    done
    printf '</body>\n</html>\n'
  } >"$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$pasta/index.html"
}

rm -rf _site
cp -r site _site
for pasta in pacotes/*/; do
  nome=$(basename "$pasta")
  apt_repositorio "$nome"
  rpm_repositorio "$nome"
done
(cd pacotes && ls -- */*.deb */*.rpm) | sort >_site/versoes.txt
find _site -type d | sort -r | while read -r pasta; do
  listagem "$pasta"
done
echo "Assinado com $CHAVE:"
cat _site/versoes.txt
