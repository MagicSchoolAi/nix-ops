# Update script for vercel-cli package
# Checks npm registry for new versions and updates the nix derivation
{ pkgs, pog, ... }:
let
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  sed = "${pkgs.gnused}/bin/sed";
  nix-prefetch-url = "${pkgs.nix}/bin/nix-prefetch-url";
in
pog {
  name = "nupdate_vercel_cli";
  description = "Check and update vercel-cli to the latest npm version";
  script = helpers: with helpers; ''
    NPM_REGISTRY_URL="https://registry.npmjs.org"
    PACKAGE_NAME="vercel"
    PACKAGE_NIX="mods/pkgs/vercel-cli.nix"

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

    # Clear the deps outputHash so the next build computes the correct one
    # The build will fail with the correct hash, which must be substituted
    ${sed} -i 's|outputHash = "sha256-[^"]*"|outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' "$PACKAGE_NIX"

    green "Updated $PACKAGE_NIX to version $latest_version"
    yellow "NOTE: outputHash has been cleared. Run 'nix-build -A vercel-cli' to get the correct hash, then update it."

    # Attempt to build and extract the correct hash
    green "Building to compute deps hash..."
    correct_hash=$(nix-build -A vercel-cli 2>&1 | ${sed} -n 's/.*got:    \(sha256-[^ ]*\)/\1/p')
    if [ -n "$correct_hash" ]; then
      green "Computed deps hash: $correct_hash"
      ${sed} -i "s|outputHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"|outputHash = \"$correct_hash\"|" "$PACKAGE_NIX"

      # Verify the build succeeds
      green "Verifying build..."
      if nix-build -A vercel-cli >/dev/null 2>&1; then
        green "Build succeeded!"
      else
        die "Build failed after setting hash. Manual intervention needed." 1
      fi
    else
      die "Failed to compute deps hash. Manual intervention needed." 1
    fi

    green "Updated $PACKAGE_NIX to version $latest_version"

    # Show what changed
    echo ""
    green "Changes made:"
    git diff --stat "$PACKAGE_NIX" 2>/dev/null || true
  '';
}
