{
  description = "EverCal Flutter desktop application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.flutterPackages.v3_41.buildFlutterApplication rec {
            pname = "evercal";
            version = "1.0.0";
            src = ./.;

            autoPubspecLock = ./pubspec.lock;

            # Upstream binary is named "ever_cal"; provide a stable alias.
            postInstall = ''
              ln -s $out/bin/ever_cal $out/bin/evercal
            '';
          };
        }
      );
    };
}
