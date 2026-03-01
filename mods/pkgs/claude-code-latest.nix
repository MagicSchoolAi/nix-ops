# Inspired by https://github.com/sadjow/claude-code-nix
{ lib
, stdenv
, fetchurl
, nodejs_22
, cacert

}:

let
  version = "2.1.63";

  claudeCodeTarball = fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
    sha256 = "0xxsgjz0gkfmgxgaifwy5c15vziagpvjd4nb01wimldicq2ysz3q";
  };
in
stdenv.mkDerivation {
  pname = "claude-code-latest";
  inherit version;

  src = claudeCodeTarball;

  nativeBuildInputs = [ nodejs_22 ];
  buildInputs = [ nodejs_22 cacert ];

  dontUnpack = true;
  dontPatchShebangs = true;

  installPhase = ''
        runHook preInstall

        export HOME=$TMPDIR
        export npm_config_cache=$TMPDIR/.npm
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

        mkdir -p $out/lib/node_modules
        mkdir -p $out/bin

        # Install claude-code from pre-fetched tarball
        ${nodejs_22}/bin/npm install \
          --global \
          --prefix $out \
          --offline \
          --ignore-scripts \
          --no-audit \
          --no-fund \
          ${claudeCodeTarball}

        # Remove the symlink created by npm and create our own wrapper
        rm -f $out/bin/claude

        # Create wrapper script that uses bundled Node.js
        cat > $out/bin/claude << 'WRAPPER'
    #!/usr/bin/env bash
    export NODE_PATH="@out@/lib/node_modules"
    export SSL_CERT_FILE="@cacert@/etc/ssl/certs/ca-bundle.crt"
    export DISABLE_AUTOUPDATER=1
    unset DEV
    exec "@node@" "@out@/lib/node_modules/@anthropic-ai/claude-code/cli.js" "$@"
    WRAPPER

        substituteInPlace $out/bin/claude \
          --replace-fail "@out@" "$out" \
          --replace-fail "@cacert@" "${cacert}" \
          --replace-fail "@node@" "${nodejs_22}/bin/node"

        chmod +x $out/bin/claude

        runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code CLI - AI-powered coding assistant by Anthropic";
    homepage = "https://github.com/anthropics/claude-code";
    license = licenses.unfree;
    platforms = platforms.all;
    mainProgram = "claude";
  };
}
