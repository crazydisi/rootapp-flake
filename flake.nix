{
  description = "Standalone RootApp package, auto-updated via GitHub Actions.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      version = "unstable-2026-05-21";

      sources = {
        x86_64-linux = {
          url = "https://installer.rootapp.com/installer/Linux/X64/Root.AppImage";
          hash = "sha256-zC8LgzPMA5QjBL2EXmtEUmj62fEKwFf9nAwDGSbW4As=";
        };
        aarch64-linux = {
          url = "https://installer.rootapp.com/installer/Linux/Arm64/Root.AppImage";
          hash = "sha256-uHTrtUP0xozTFFebT51tyBPrRHfDk5MsrvIf3iQ7XfM=";
        };
      };

      mkRootapp = pkgs:
        pkgs.appimageTools.wrapType2 {
          pname = "rootapp";
          inherit version;

          src = pkgs.fetchurl sources.${pkgs.stdenv.hostPlatform.system};

          extraInstallCommands = ''
            mkdir -p $out/share/icons/hicolor/256x256/apps
            cp ${./rootapp.png} $out/share/icons/hicolor/256x256/apps/rootapp.png

            mkdir -p $out/share/applications
            cat > $out/share/applications/rootapp.desktop <<EOF
            [Desktop Entry]
            Type=Application
            Name=RootApp
            GenericName=RootApp Client
            Exec=rootapp %U
            Icon=rootapp
            Comment=Root Field Service Management
            Categories=Utility;
            Terminal=false
            StartupWMClass=Root
            EOF
          '';

          meta = with pkgs.lib; {
            description = "RootApp Linux client (AppImage wrapper)";
            longDescription = ''
              Standalone Nix flake that wraps the upstream RootApp AppImage with
              appimageTools.wrapType2 and installs an icon plus .desktop entry.
              The AppImage hash is pinned and auto-bumped by GitHub Actions on
              every upstream release.
            '';
            homepage = "https://www.rootapp.com/";
            downloadPage = "https://www.rootapp.com/download";
            license = licenses.unfree;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
            platforms = systems;
            mainProgram = "rootapp";
          };
        };
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          rootapp = mkRootapp pkgs;
          default = rootapp;
        });

      apps = forAllSystems (system: rec {
        rootapp = {
          type = "app";
          program = "${self.packages.${system}.rootapp}/bin/rootapp";
          meta.description = "Launch RootApp without installing.";
        };
        default = rootapp;
      });

      overlays.default = final: _prev: {
        rootapp = mkRootapp final;
      };

      nixosModules.default = { config, lib, pkgs, ... }:
        let cfg = config.programs.rootapp;
        in {
          options.programs.rootapp = {
            enable = lib.mkEnableOption "RootApp desktop client";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.rootapp;
              defaultText = lib.literalExpression "rootapp.packages.\${system}.rootapp";
              description = "Which RootApp package to install.";
            };
          };
          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
          };
        };

      homeManagerModules.default = { config, lib, pkgs, ... }:
        let cfg = config.programs.rootapp;
        in {
          options.programs.rootapp = {
            enable = lib.mkEnableOption "RootApp desktop client";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.rootapp;
              defaultText = lib.literalExpression "rootapp.packages.\${system}.rootapp";
              description = "Which RootApp package to install.";
            };
          };
          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
          };
        };

      checks = forAllSystems (system: {
        build = self.packages.${system}.rootapp;
      });

      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.nixpkgs-fmt);

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [ nixpkgs-fmt jq gnused curl ];
          };
        });
    };
}
