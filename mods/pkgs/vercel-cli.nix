{ lib, buildNpmPackage, fetchurl, nodejs_22, makeWrapper }:
let
  version = "50.35.0";
in
buildNpmPackage {
  pname = "vercel-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/vercel/-/vercel-${version}.tgz";
    sha256 = "17srrszijrhk2mj8964njv82gjqmi2ckvfw07xhk3bxmki1dyisi";
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

  npmDepsHash = "sha256-4U9jfAwOnq8sbVlPibTOUkr7FDZWMt7WADy5xxf+hVk=";

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
