{ lib, stdenv, fetchurl, nodejs_22, makeWrapper }:
let
  version = "50.27.1";
  src = fetchurl {
    url = "https://registry.npmjs.org/vercel/-/vercel-${version}.tgz";
    sha256 = "1bihq9bxiyk2p5ahz3qnkzizjjqfl0l72mpr30fmcv9771m5sbmc";
  };
in
stdenv.mkDerivation {
  pname = "vercel-cli";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ nodejs_22 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/vercel $out/bin
    cp -r dist $out/lib/vercel/dist

    makeWrapper ${nodejs_22}/bin/node $out/bin/vercel \
      --add-flags "$out/lib/vercel/dist/vc.js"

    makeWrapper ${nodejs_22}/bin/node $out/bin/vc \
      --add-flags "$out/lib/vercel/dist/vc.js"

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
