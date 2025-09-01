final: prev:
let
  inherit (final.lib.attrsets) attrValues;
  j = with final.jacobi; {
    inherit jfmt nixup nix_hash_magicschool nupdate_latest_github dtools ktools nixcache terraform_1-5-5;
  };
in
{
  inherit (final.jacobi) pog;
  inherit (final.kwbauson) better-comma;
  magicschool = final.buildEnv {
    name = "magicschool";
    paths = (final.lib.flatten (attrValues j)) ++ (attrValues final.custom) ++
    (with final; [
      claude-code
      codex
      gh
      git
      gnused
      jq
      nixpkgs-fmt
      nodejs_24
      npm-check-updates
      overmind
      pnpm_10
      stripe-cli
      toybox
      typescript
    ]) ++
    (with final.nodePackages; [
      vercel
    ]);
  };
} // j
