{
  description = "nix-darwin, NixOS and home-manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # NixOS hosts track the channel gated on NixOS tests; nixpkgs-unstable only
    # gates on package builds, which is fine for macOS but not for a whole OS.
    nixos.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Single packages that can't wait for a channel bump (see hosts/); drop
    # once nixos-unstable catches up.
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos";
    };

    # Secure Boot for NixOS. Pinned to a release tag, as upstream recommends.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixos";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos,
      nixpkgs-master,
      nix-darwin,
      home-manager,
      nixos-hardware,
      disko,
      lanzaboote,
      ...
    }:
    let
      user = "carlosmarques";
      forAllSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      homeManager = platformModule: {
        home-manager = {
          useGlobalPkgs = true;
          backupFileExtension = "hm-backup";
          # Platform module first: module merging puts its definitions (e.g.
          # home.packages) after this list's later entries, keeping the
          # Mac's package order identical to the pre-split home.nix.
          users.${user}.imports = [
            platformModule
            ./home
          ];
        };
      };
    in
    {
      # The Mac's real hostname comes from MDM and embeds its serial number, so
      # this isn't named after it: switch with `--flake .#m4-machine-broke`
      # (the `rebuild` alias in home/darwin.nix).
      darwinConfigurations.m4-machine-broke = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit user; };
        modules = [
          ./darwin.nix
          home-manager.darwinModules.home-manager
          (homeManager ./home/darwin.nix)
        ];
      };

      nixosConfigurations.framework-machine-broke = nixos.lib.nixosSystem {
        specialArgs = { inherit user nixos-hardware nixpkgs-master; };
        modules = [
          ./hosts/framework
          disko.nixosModules.disko
          lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          (homeManager ./home/linux.nix)
        ];
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # Usage: nix flake new -t ~/configs <dir>
      templates.default = {
        path = ./templates/default;
        description = "Flake with a dev shell, wired for direnv (`use flake`)";
      };
    };
}
