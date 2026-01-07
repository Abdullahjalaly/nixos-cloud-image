{
  description = "NixOS Cloud Image Builder - Universal images for any cloud provider";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      darwinPkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in
    {
      nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          ({ config, lib, pkgs, ... }: {
            system.stateVersion = "25.11";
          })
        ];
      };

      # Amazon EC2 image - works as generic cloud raw image
      nixosConfigurations.hetzner-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
          ./configuration.nix
          ({ config, lib, pkgs, ... }: {
            system.stateVersion = "25.11";
            # EC2 image creates raw disk we can use
            ec2.hvm = true;
          })
        ];
      };

      # Raw disk image package for GitHub runner builds
      packages.x86_64-linux.diskImage =
        self.nixosConfigurations.hetzner-image.config.system.build.amazonImage;

      # Development shell for macOS and Linux
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          actionlint
          yamllint
          shellcheck
        ];
      };

      devShells.aarch64-darwin.default = darwinPkgs.mkShell {
        buildInputs = with darwinPkgs; [
          actionlint
          yamllint
          shellcheck
        ];
      };
    };
}
