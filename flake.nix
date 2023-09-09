{
  description = "System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    darwinVariables = import ./darwin-variables.nix;

    home = import ./home.nix;

    darwinSystem = import ./darwin.nix { 
      inherit nix-darwin home-manager home darwinVariables;
    };
  in
  {
    darwinConfigurations."${darwinVariables.hostname}" = darwinSystem;

    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations."${darwinVariables.hostname}".pkgs;
  };
}