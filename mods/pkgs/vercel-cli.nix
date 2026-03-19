{ lib, stdenv, fetchurl, nodejs_22, makeWrapper, cacert }:
let
  version = "50.33.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/vercel/-/vercel-${version}.tgz";
    sha256 = "1dkvkcr0yfbj7jbd5j0spadkflwv3w22b66kzq1agwab09bb0bjv";
  };

  depsHash = {
    x86_64-linux = "sha256-zXyrzYTbuIfOl5fC1sdd7Znh4fbh3VSNSkuaIGemaTE=";
    aarch64-linux = "sha256-zXyrzYTbuIfOl5fC1sdd7Znh4fbh3VSNSkuaIGemaTE=";
    x86_64-darwin = "sha256-Ta0lMArVcKpMIxaLrIMTCexuilewa3oDW2e9FSJSl8g=";
    aarch64-darwin = "sha256-Ta0lMArVcKpMIxaLrIMTCexuilewa3oDW2e9FSJSl8g=";
  };

  deps = stdenv.mkDerivation {
    pname = "vercel-cli-deps";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [ nodejs_22 cacert ];

    buildPhase = ''
      export HOME=$TMPDIR
      export npm_config_cache=$TMPDIR/.npm
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

      mkdir -p $out
      ${nodejs_22}/bin/npm install \
        --global \
        --prefix $out \
        --omit=dev \
        --ignore-scripts \
        --no-audit \
        --no-fund \
        ${src}
    '';

    dontInstall = true;
    dontFixup = true;

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = depsHash.${stdenv.hostPlatform.system};
  };
in
stdenv.mkDerivation {
  pname = "vercel-cli";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin
    cp -r ${deps}/lib/node_modules $out/lib/node_modules

    makeWrapper ${nodejs_22}/bin/node $out/bin/vercel \
      --add-flags "$out/lib/node_modules/vercel/dist/vc.js"

    makeWrapper ${nodejs_22}/bin/node $out/bin/vc \
      --add-flags "$out/lib/node_modules/vercel/dist/vc.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Vercel CLI";
    homepage = "https://vercel.com";
    license = licenses.asl20;
    platforms = platforms.all;
    mainProgram = "vercel";
  };
}
