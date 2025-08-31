{ flake ? import ./flake-compat.nix
, nixpkgs ? flake.inputs.nixpkgs
, overlays ? [ ]
, config ? { }
, system ? builtins.currentSystem
}:
import nixpkgs {
  inherit system;
  overlays = [
    (_: _: { inherit flake; nixpkgsRev = nixpkgs.rev; jacobi = flake.inputs.jacobi.packages.${system}; kwbauson = flake.inputs.kwbauson.packages.${system}; })
  ] ++ (import ./mods/default.nix) ++ overlays;
  config = {
    allowUnfree = true;
    permittedInsecurePackages = [ ];
  } // config;
}
