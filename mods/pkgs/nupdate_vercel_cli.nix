# Update script for vercel-cli package
# Checks npm registry for new versions and updates the nix derivation
# Also regenerates the package-lock.json and npmDepsHash for buildNpmPackage
{ pkgs, pog, ... }:
let
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  sed = "${pkgs.gnused}/bin/sed";
  nix-prefetch-url = "${pkgs.nix}/bin/nix-prefetch-url";
  node = "${pkgs.nodejs_22}/bin/node";
  npm = "${pkgs.nodejs_22}/bin/npm";
  prefetch-npm-deps = "${pkgs.prefetch-npm-deps}/bin/prefetch-npm-deps";
  jfmt = "${pkgs.jfmt}/bin/jfmt";
in
pog {
  name = "nupdate_vercel_cli";
  description = "Check and update vercel-cli to the latest npm version";
  script = helpers: with helpers; ''
    NPM_REGISTRY_URL="https://registry.npmjs.org"
    PACKAGE_NAME="vercel"
    PACKAGE_NIX="mods/pkgs/vercel-cli.nix"
    PACKAGE_LOCK="mods/pkgs/vercel-cli-lock.json"

    # Get current version from the nix file
    get_current_version() {
      ${sed} -n 's/.*version = "\([^"]*\)".*/\1/p' "$PACKAGE_NIX" | head -1
    }

    # Get latest version from npm registry
    get_latest_version() {
      ${curl} -s "$NPM_REGISTRY_URL/$PACKAGE_NAME/latest" | ${jq} -r '.version'
    }

    # Fetch tarball hash using nix-prefetch-url
    fetch_tarball_hash() {
      local version="$1"
      local tarball_url="$NPM_REGISTRY_URL/$PACKAGE_NAME/-/$PACKAGE_NAME-$version.tgz"
      ${nix-prefetch-url} "$tarball_url" 2>/dev/null | tail -1
    }

    current_version=$(get_current_version)
    latest_version=$(get_latest_version)

    green "Current version: $current_version"
    green "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
      green "vercel-cli is already up to date!"
      exit 0
    fi

    yellow "Update available: $current_version -> $latest_version"
    green "Fetching tarball hash..."

    new_hash=$(fetch_tarball_hash "$latest_version")
    if [ -z "$new_hash" ]; then
      die "Failed to fetch tarball hash for version $latest_version" 1
    fi

    green "New hash: $new_hash"

    # Update version in the nix file
    ${sed} -i "s/version = \"$current_version\"/version = \"$latest_version\"/" "$PACKAGE_NIX"

    # Update tarball hash in the nix file (first sha256 occurrence)
    ${sed} -i "0,/sha256 = \"[^\"]*\"/{s/sha256 = \"[^\"]*\"/sha256 = \"$new_hash\"/}" "$PACKAGE_NIX"

    # Regenerate package-lock.json for the new version
    green "Regenerating package-lock.json..."
    TMPDIR=$(mktemp -d)
    tarball_url="$NPM_REGISTRY_URL/$PACKAGE_NAME/-/$PACKAGE_NAME-$latest_version.tgz"
    ${curl} -sL "$tarball_url" | tar xz -C "$TMPDIR"
    # Strip devDependencies before generating lockfile
    ${node} -e "
      const pkg = JSON.parse(require('fs').readFileSync('$TMPDIR/package/package.json', 'utf8'));
      delete pkg.devDependencies;
      require('fs').writeFileSync('$TMPDIR/package/package.json', JSON.stringify(pkg, null, 2));
    "
    (cd "$TMPDIR/package" && ${npm} install --package-lock-only --ignore-scripts 2>/dev/null)
    cp "$TMPDIR/package/package-lock.json" "$PACKAGE_LOCK"
    rm -rf "$TMPDIR"

    # Format lockfile with jfmt to pass lint checks
    ${jfmt} "$PACKAGE_LOCK"

    # Compute new npmDepsHash (must be after jfmt, as formatting changes the hash)
    green "Computing npmDepsHash..."
    new_npm_deps_hash=$(${prefetch-npm-deps} "$PACKAGE_LOCK" 2>/dev/null)
    if [ -z "$new_npm_deps_hash" ]; then
      die "Failed to compute npmDepsHash" 1
    fi

    green "New npmDepsHash: $new_npm_deps_hash"

    # Update npmDepsHash in the nix file
    ${sed} -i "s|npmDepsHash = \"[^\"]*\"|npmDepsHash = \"$new_npm_deps_hash\"|" "$PACKAGE_NIX"

    green "Updated $PACKAGE_NIX to version $latest_version"

    # Show what changed
    echo ""
    green "Changes made:"
    git diff --stat "$PACKAGE_NIX" "$PACKAGE_LOCK" 2>/dev/null || true
  '';
}
