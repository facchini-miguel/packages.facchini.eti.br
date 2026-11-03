# packages.facchini.eti.br

Linux package repository (apt and dnf) for Miguel Facchini's software, published on GitHub Pages
at https://packages.facchini.eti.br.

Being prepared: the signed apt (`/deb`) and dnf (`/rpm`) repositories of
[Kaladrius](https://github.com/facchini-miguel/kaladrius) will be published here, so that
`apt upgrade` and `dnf upgrade` bring its new versions. Until then, its packages are on its
[releases page](https://github.com/facchini-miguel/kaladrius/releases/latest).

- `site/`: what is published.
- `.github/workflows/publicar.yml`: publishes `site/` on every push to `main`.
