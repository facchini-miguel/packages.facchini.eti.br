# packages.facchini.eti.br

Linux package repositories for Miguel Facchini's software, published on GitHub Pages at
https://packages.facchini.eti.br, one folder per software. Today it carries
[Kaladrius](https://github.com/facchini-miguel/kaladrius) (amd64). How to install each one is in
its own documentation ([Kaladrius](https://kaladrius-docs.facchini.eti.br/installation/linux-package));
this site only serves the packages.

| Path | What |
|---|---|
| `/<name>/deb` | apt repository: suite `stable`, component `main` |
| `/<name>/deb/<name>.sources` | its apt source (deb822, with the key inside), for `/etc/apt/sources.list.d/` |
| `/<name>/rpm` | dnf and zypper repository |
| `/<name>/rpm/<name>.repo` | its `.repo` file, for `/etc/yum.repos.d/` or `/etc/zypp/repos.d/` |
| `/facchini.asc` | the signing key of every repository (RSA 4096, fingerprint `9D3A 0438 FF6C 00F9 1CA1 A0AB A5C3 35B2 EB36 7ABA`) |
| `/versoes.txt` | the packages published |

Every folder without a page of its own gets a plain listing of its files.

## How it is built

`.github/workflows/publicar.yml` runs on every push, every hour and by hand:

1. `baixar.sh` downloads into `pacotes/<name>/` the `.deb` and `.rpm` attached to each GitHub
   release of the projects it lists, each checked against its release's `SHA256SUMS`. Every
   version stays, so an older one can still be installed (`apt install kaladrius=0.54.0-1`).
2. On the hourly run, nothing is published when the list of packages is the one already online.
3. `construir.sh` copies `site/` and, for each software, builds the apt metadata
   (`apt-ftparchive`; `InRelease` and `Release.gpg` signed) and its `.sources`, signs every
   `.rpm` (`rpmsign`), builds the rpm metadata (`createrepo_c`; `repomd.xml.asc` signed) and
   writes its `.repo`. It refuses to run when the key in the `GPG_CHAVE_PRIVADA` secret is not
   the one in `site/facchini.asc`.

The signing key's private part exists only in the repository secret `GPG_CHAVE_PRIVADA` and in
the owner's offline backup. It is imported into a temporary GPG home that is deleted at the end.

## Adding software

1. Add its GitHub repository to `PROJETOS` in `baixar.sh`; the repository's name becomes its
   folder. Its releases must attach amd64 `.deb` and `.rpm` packages and a `SHA256SUMS`.
2. Add a row to the table on `site/index.html` (the three languages), linking to its
   installation guide.
3. In its documentation, the installation commands: download `/<name>/deb/<name>.sources` into
   `/etc/apt/sources.list.d/`, or `/<name>/rpm/<name>.repo` into `/etc/yum.repos.d/` (dnf) or
   with `zypper addrepo`.
