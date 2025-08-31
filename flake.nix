{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    jacobi.url = "github:jpetrucciani/nix";
    kwbauson.url = "github:kwbauson/cfg";
  };
  outputs = { self, ... }:
    let
      inherit (self.inputs.nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      packages = forAllSystems (system: import ./. { flake = self; inherit system; });
    in
    {
      inherit packages;
      pins = self.inputs;
      devShells = forAllSystems (
        system:
        let pkgs = packages.${system}; in {
          default = pkgs.mkShell {
            name = "nix";
            buildInputs = with pkgs; [
              jfmt
              nixup
              nix_hash_magicschool
            ];
          };
        }
      );
    };
}
