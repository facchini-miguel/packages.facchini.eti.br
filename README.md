# packages.facchini.eti.br

Linux package repository for Miguel Facchini's software, published on GitHub Pages at
https://packages.facchini.eti.br. Today it carries [Kaladrius](https://github.com/facchini-miguel/kaladrius)
(amd64): with the repository added, `apt upgrade`, `dnf upgrade` and `zypper update` bring its
new versions. How to add it: the site's home page.

| Path | What |
|---|---|
| `/deb` | apt repository: `deb [signed-by=…] https://packages.facchini.eti.br/deb stable main` |
| `/rpm` | dnf and zypper repository; `/rpm/facchini.repo` is its `.repo` file |
| `/chave.asc` | the signing key (RSA 4096, fingerprint `9D3A 0438 FF6C 00F9 1CA1 A0AB A5C3 35B2 EB36 7ABA`) |
| `/versoes.txt` | the packages published |

## How it is built

`.github/workflows/publicar.yml` runs on every push, every hour and by hand:

1. `baixar.sh` downloads the `.deb` and `.rpm` attached to each GitHub release of the projects it
   lists, each checked against its release's `SHA256SUMS`. Every version stays, so an older one
   can still be installed (`apt install kaladrius=0.54.0-1`).
2. On the hourly run, nothing is published when the list of packages is the one already online.
3. `construir.sh` copies `site/`, builds the apt metadata (`apt-ftparchive`; `InRelease` and
   `Release.gpg` signed), signs every `.rpm` (`rpmsign`), builds the rpm metadata
   (`createrepo_c`; `repomd.xml.asc` signed) and writes `facchini.repo`. It refuses to run when the
   key in the `GPG_CHAVE_PRIVADA` secret is not the one in `site/chave.asc`.

The signing key's private part exists only in the repository secret `GPG_CHAVE_PRIVADA` and in
the owner's offline backup. It is imported into a temporary GPG home that is deleted at the end.

## Adding software

Add its GitHub repository to `PROJETOS` in `baixar.sh`. Its releases must attach amd64 `.deb`
and `.rpm` packages and a `SHA256SUMS`.
