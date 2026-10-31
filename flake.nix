{
  description = "ai-setup: the agent skills, hooks and tools I carry to every host and every project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      homeManagerModules.default = ./nix/module.nix;

      nixosModules.telemetry = ./nix/telemetry-server.nix;

      packages = forAllSystems (pkgs: {
        default = pkgs.callPackage ./nix/package.nix { };
      });

      checks = forAllSystems (pkgs: {
        ai-setup = pkgs.callPackage ./nix/package.nix { };
      });
    };
}
