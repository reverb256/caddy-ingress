{
  description = "Caddy ingress controller with custom modules (security, rate-limit, cache)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      caddy-with-modules = pkgs.callPackage ./pkgs/caddy-with-modules { };

      caddy-ingress-image = pkgs.callPackage ./pkgs/caddy-ingress-image {
        inherit caddy-with-modules;
      };
    in
    {
      packages.${system} = {
        inherit caddy-with-modules caddy-ingress-image;
        default = caddy-with-modules;
      };

      nixosModules = {
        caddy = import ./modules/caddy.nix;
        caddy-common = import ./modules/caddy-common.nix;
        default = self.nixosModules.caddy;
      };

      kubernetesModules.default = import ./kubernetes/module.nix;

      apps.${system} = {
        load-image = {
          type = "app";
          program = "${pkgs.writeShellScriptBin "load-caddy-image" ''
            ${pkgs.docker}/bin/docker load < ${caddy-ingress-image}
          ''}/bin/load-caddy-image";
        };
      };
    };
}
