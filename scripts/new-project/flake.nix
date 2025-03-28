{
  description = "Template Flake";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsForAllSystems = forAllSystems (system: import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      });

      makeDevShell = system:
        let
          inherit pkgsForAllSystems;
          pkgs = pkgsForAllSystems.${system};

          isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
          darwinPackages = if isDarwin then [ ] else [ ];
        in
        pkgs.mkShell {
          buildInputs = [
          ] ++ darwinPackages;

          shellHook = ''
          '';
        };

    in
    {
      devShells = forAllSystems (system: {
        default = makeDevShell system;
      });

      packages = forAllSystems (system:
        let
          pkgs = pkgsForAllSystems.${system};
        in
        { });
    };
}
