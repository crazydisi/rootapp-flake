# RootApp NixOS Flake

[![CI](https://github.com/crazydisi/rootapp-flake/actions/workflows/ci.yml/badge.svg)](https://github.com/crazydisi/rootapp-flake/actions/workflows/ci.yml)
[![Auto-Update](https://github.com/crazydisi/rootapp-flake/actions/workflows/update.yml/badge.svg)](https://github.com/crazydisi/rootapp-flake/actions/workflows/update.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL_3.0-blue.svg)](./LICENSE)

A zero-maintenance Nix flake for installing **[RootApp](https://www.rootapp.com/)** on NixOS, Home Manager, or any system with Nix.

Upstream ships a single AppImage and no `.deb`, `.rpm`, or Flatpak. This flake wraps that AppImage with `appimageTools.wrapType2`, registers a `.desktop` entry plus icon, and pins the binary by SRI hash for both `x86_64-linux` and `aarch64-linux`. A scheduled GitHub Actions job re-checks upstream every day and commits a new hash whenever the AppImage changes — so consumers just bump the flake input.

## Features

- **Declarative install** — no manual `chmod +x`, no rogue AppImage in `~/Downloads`
- **Multi-arch** — `x86_64-linux` and `aarch64-linux` both pinned and built in CI
- **First-class outputs** — `packages`, `apps`, `overlays`, `nixosModules`, `homeManagerModules`, `checks`, `formatter`, `devShells`
- **Real desktop integration** — 256×256 icon and `.desktop` entry land in the correct hicolor paths
- **Auto-update** — daily cron bumps the AppImage hash and version; weekly cron opens a PR for `flake.lock`
- **Reproducible** — every commit pins a specific AppImage by SHA-256
- **CI-verified** — every push runs `nix flake check`, `nix fmt --check`, and a real `nix build`

## Quick start

Try it once without installing:

```sh
nix run --impure github:crazydisi/rootapp-flake
```

> `--impure` is required because RootApp ships as a closed-source AppImage, marked `license.unfree` in this flake's `meta`. See [Allowing unfree](#allowing-unfree) below.

## Install

Replace `github:crazydisi/rootapp-flake` with your own fork if you maintain one.

### NixOS module (recommended)

Adds the package and a typed option set under `programs.rootapp`.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rootapp.url = "github:crazydisi/rootapp-flake";
  };

  outputs = { self, nixpkgs, rootapp, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        rootapp.nixosModules.default
        ({ ... }: {
          programs.rootapp.enable = true;
          nixpkgs.config.allowUnfree = true;
        })
      ];
    };
  };
}
```

### Home Manager module

```nix
{
  inputs.rootapp.url = "github:crazydisi/rootapp-flake";

  outputs = { self, home-manager, rootapp, ... }: {
    homeConfigurations.me = home-manager.lib.homeManagerConfiguration {
      modules = [
        rootapp.homeManagerModules.default
        ({ ... }: {
          programs.rootapp.enable = true;
          nixpkgs.config.allowUnfree = true;
        })
      ];
    };
  };
}
```

### Overlay (add to your nixpkgs)

```nix
{
  nixpkgs.overlays = [ inputs.rootapp.overlays.default ];
  environment.systemPackages = [ pkgs.rootapp ];
}
```

### Plain `environment.systemPackages`

```nix
environment.systemPackages = [
  inputs.rootapp.packages.${pkgs.system}.default
];
```

### Ad-hoc shell

```sh
nix shell --impure github:crazydisi/rootapp-flake
```

## Allowing unfree

The wrapped binary is closed-source, so the derivation's `meta.license` is `unfree`. Choose **one** of:

| Context              | What to set                                                                |
|----------------------|----------------------------------------------------------------------------|
| NixOS / Home Manager | `nixpkgs.config.allowUnfree = true;`                                       |
| Scoped allowlist     | `nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "rootapp";` |
| Ad-hoc CLI           | `export NIXPKGS_ALLOW_UNFREE=1` and pass `--impure`                        |

## How auto-update works

Two GitHub Actions workflows keep things fresh:

| Workflow                 | Cadence            | What it does                                                                                       |
|--------------------------|--------------------|----------------------------------------------------------------------------------------------------|
| `.github/workflows/update.yml`     | daily, 03:17 UTC   | Prefetches both AppImages, rewrites hashes + `version` if upstream changed, builds, then commits   |
| `.github/workflows/flake-lock.yml` | weekly, Mondays    | Opens a PR with a fresh `nixpkgs` lock so CVE fixes flow through                                  |
| `.github/workflows/ci.yml`         | on push / PR       | `nix fmt --check`, `nix flake check`, and a real `nix build` of `x86_64-linux`                    |

Downstream consumers pick up new releases by running `nix flake update` against this input.

## Manual hash bump

If you need to refresh hashes locally (e.g. testing before the cron fires):

```sh
nix store prefetch-file https://installer.rootapp.com/installer/Linux/X64/Root.AppImage   --json | jq -r .hash
nix store prefetch-file https://installer.rootapp.com/installer/Linux/Arm64/Root.AppImage --json | jq -r .hash
```

Paste the results into the matching `hash = "..."` lines in [flake.nix](./flake.nix).

## Development

```sh
nix develop          # nixpkgs-fmt, jq, gnused, curl
nix fmt              # format flake.nix
nix flake check --impure
nix build .#packages.x86_64-linux.rootapp --impure
nix run --impure
```

## Repository layout

```text
.
├── flake.nix                       # package, overlay, modules, checks, formatter, devShell
├── rootapp.png                     # 256×256 icon installed into hicolor
├── LICENSE                         # GPL-3.0 (wrapper code only)
├── README.md
└── .github/workflows/
    ├── ci.yml                      # build + fmt + flake check on every push
    ├── update.yml                  # daily AppImage hash bump
    └── flake-lock.yml              # weekly nixpkgs lock bump (PR)
```

## License

The Nix expressions and CI glue in this repo are GPL-3.0 (see [LICENSE](./LICENSE)). RootApp itself is governed by [its own terms](https://www.rootapp.com/) — this repo only pins a public download URL and the wrapping logic, never the binary.
