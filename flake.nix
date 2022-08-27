{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/21.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      supportedSystems = {
        "${flake-utils.lib.system.aarch64-darwin}" = "macos-aarch64";
        "${flake-utils.lib.system.x86_64-darwin}" = "macos-x86_64";
      };
    in
      flake-utils.lib.eachSystem (builtins.attrNames supportedSystems) (
        system: let
          pkgs = import nixpkgs {
            system =
              if system == flake-utils.lib.system.aarch64-darwin
              then flake-utils.lib.system.x86_64-darwin
              else system;
          };

          error = message: builtins.throw ("[nix-quill] " + message);

          quillRelease = options:
            let
              systemName =
                if builtins.hasAttr options.system supportedSystems
                then supportedSystems.${options.system}
                else error ("unsupported system: " + options.system);

              sha256 =
                if builtins.hasAttr options.system options.sha256
                then options.sha256.${options.system}
                else error ("sha256 not provided for system: " + options.system);

              url = "https://github.com/dfinity/quill/releases/download/${options.release}";

              bin = "quill-${systemName}";
            in
              pkgs.stdenv.mkDerivation {
                name = "quill-${options.release}-${systemName}";
                src = pkgs.fetchurl {
                  inherit sha256;
                  url = "${url}/${bin}";
                };
                phases = [
                  "installPhase"
                  "fixupPhase"
                ];
                buildInputs = [
                  pkgs.makeWrapper
                ];
                installPhase = ''
                  mkdir -p $out/bin
                  cp $src $out/bin/quill
                  chmod +x $out/bin/quill
                '';
                fixupPhase = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
                  wrapProgram $out/bin/quill --prefix DYLD_LIBRARY_PATH : ${pkgs.openssl_1_1.out}/lib
                '';
              };
        in
          rec {
            # `nix build '.#quill'`
            packages.quill = quillRelease {
              inherit system;
              release = "v0.2.17";
              sha256 = {
                "${flake-utils.lib.system.aarch64-darwin}" = "sha256-7Oh26BOJ7QSnzcNlkYdYiuJYLK7SlyaRh/3OicWM6os=";
                "${flake-utils.lib.system.x86_64-darwin}" = "sha256-7Oh26BOJ7QSnzcNlkYdYiuJYLK7SlyaRh/3OicWM6os=";
              };
            };

            # `nix build`
            defaultPackage = packages.quill;

            apps.quill = flake-utils.lib.mkApp {
              name = "quill";
              drv = packages.quill;
            };

            # `nix run`
            defaultApp = apps.quill;

            # `nix develop`
            devShell = pkgs.mkShell {
              buildInputs = [
                packages.quill
              ];
            };
          }
      );
}
