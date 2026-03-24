{ lib, buildNpmPackage, fetchurl, nodejs_22, makeWrapper }:
{ lib, buildNpmPackage, fetchurl, nodejs_22, makeWrapper }:
let
  version = "50.34.2";
in
buildNpmPackage {
  pname = "vercel-cli";
  inherit version;

  src = fetchurl {
let
  version = "50.34.2";
in
buildNpmPackage {
  pname = "vercel-cli";
  inherit version;

    url = "https://registry.npmjs.org/vercel/-/vercel-${version}.tgz";
    sha256 = "0hi306p48aymvc144q0jzvmbdi08rbmdg1yd0y3zx1389kslqpmh";
  };

  # TODO: When nixpkgs is updated to a version supporting `packageLock`,
  # replace this `postPatch` copy with the `packageLock` attribute instead.
  postPatch = ''
    cp ${./vercel-cli-lock.json} package-lock.json
    ${nodejs_22}/bin/node -e "
      const pkg = JSON.parse(require('fs').readFileSync('package.json', 'utf8'));
      delete pkg.devDependencies;
      require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
  '';

  npmDepsHash = "sha256-DCH64gt9DPMtHfSKRZzoI6FJG/nuBwD4hT+TWvp7ym4=";

  nodejs = nodejs_22;
  dontNpmBuild = true;
  npmInstallFlags = [ "--omit=dev" ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # Remove npm-generated symlinks and create our own wrappers
    rm -f $out/bin/vercel $out/bin/vc

    makeWrapper ${nodejs_22}/bin/node $out/bin/vercel \
      --add-flags "$out/lib/node_modules/vercel/dist/vc.js"

    makeWrapper ${nodejs_22}/bin/node $out/bin/vc \
      --add-flags "$out/lib/node_modules/vercel/dist/vc.js"
  '';

  meta = with lib; {
    description = "Vercel CLI";
    homepage = "https://vercel.com";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "vercel";
  };
}
