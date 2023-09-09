{
  description = "System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    home = import ./home.nix;
    darwinSystem = import ./darwin.nix { 
      inherit nix-darwin home-manager home;
    };
  in
  {
    darwinConfigurations."Carloss-MacBook-Pro" = darwinSystem;

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."Carloss-MacBook-Pro".pkgs;
  };
}