{
  description = "EverCal Flutter desktop application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
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

          desktopItem = pkgs.makeDesktopItem {
            name = "evercal";
            desktopName = "EverCal";
            comment = "A beautiful Material 3 Expressive calendar";
            exec = "evercal";
            icon = "evercal";
            categories = [
              "Office"
              "Calendar"
            ];
          };
        in
        {
          default = pkgs.flutterPackages.v3_41.buildFlutterApplication rec {
            pname = "evercal";
            version = "1.0.0";
            src = ./.;

            autoPubspecLock = ./pubspec.lock;

            nativeBuildInputs = [ pkgs.copyDesktopItems ];
            desktopItems = [ desktopItem ];

            # Upstream binary is named "ever_cal"; provide a stable alias.
            postInstall = ''
              ln -s $out/bin/ever_cal $out/bin/evercal

              install -Dm644 ${./assets/evercal.svg} \
                $out/share/icons/hicolor/scalable/apps/evercal.svg
            '';

            meta = {
              description = "A beautiful Material 3 Expressive calendar";
              homepage = "https://github.com/HaiVuBui/EverCal";
              license = pkgs.lib.licenses.mit;
              mainProgram = "evercal";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/evercal";
        };
      });
    };
}
