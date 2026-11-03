#!/bin/bash
# Builds _site/ from site/ and the packages in pacotes/ (baixar.sh):
#   /deb  an apt repository: suite "stable", component "main", amd64
#   /rpm  a dnf/zypper repository, every package signed, and facchini.repo
#   /versoes.txt  the packages published (the hourly run compares it to skip a deploy)
# Everything is signed with the private key in GPG_CHAVE_PRIVADA, which must be the one in
# site/chave.asc (the key clients import). The key lives only in a temporary GNUPGHOME.
set -euo pipefail
cd "$(dirname "$0")"
: "${GPG_CHAVE_PRIVADA:?a chave privada (secret do repositório)}"

GNUPGHOME=$(mktemp -d)
export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT
gpg --batch --quiet --import <<<"$GPG_CHAVE_PRIVADA"
CHAVE=$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^fpr:/ {print $10; exit}')
PUBLICA=$(gpg --batch --with-colons --show-keys site/chave.asc | awk -F: '/^fpr:/ {print $10; exit}')
if [ "$CHAVE" != "$PUBLICA" ]; then
  echo "A chave do secret ($CHAVE) não é a de site/chave.asc ($PUBLICA)." >&2
  exit 1
fi
assinar() { gpg --batch --yes --local-user "$CHAVE" "$@"; }

rm -rf _site
cp -r site _site

# apt
deb=_site/deb
mkdir -p "$deb/pool/main" "$deb/dists/stable/main/binary-amd64"
cp pacotes/*.deb "$deb/pool/main/"
(
  cd "$deb"
  apt-ftparchive packages pool/main >dists/stable/main/binary-amd64/Packages
  gzip -9nk dists/stable/main/binary-amd64/Packages
  cd dists/stable
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=packages.facchini.eti.br \
    -o APT::FTPArchive::Release::Label=packages.facchini.eti.br \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    release . >../Release.tmp
  mv ../Release.tmp Release
)
assinar --clearsign -o "$deb/dists/stable/InRelease" "$deb/dists/stable/Release"
assinar --armor --detach-sign -o "$deb/dists/stable/Release.gpg" "$deb/dists/stable/Release"

# dnf / zypper
rpm=_site/rpm
mkdir -p "$rpm/pacotes"
cp pacotes/*.rpm "$rpm/pacotes/"
# Ubuntu's rpm looks for gpg under another name: the path is given.
rpmsign --define "__gpg $(command -v gpg)" --define "_gpg_name $CHAVE" --define "_gpg_path $GNUPGHOME" --addsign "$rpm"/pacotes/*.rpm >/dev/null
createrepo_c --quiet "$rpm"
assinar --armor --detach-sign -o "$rpm/repodata/repomd.xml.asc" "$rpm/repodata/repomd.xml"
cat >"$rpm/facchini.repo" <<'EOF'
[facchini]
name=packages.facchini.eti.br
baseurl=https://packages.facchini.eti.br/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.facchini.eti.br/chave.asc
EOF

(cd pacotes && ls -- *.deb *.rpm) | sort >_site/versoes.txt
echo "Assinado com $CHAVE:"
cat _site/versoes.txt
