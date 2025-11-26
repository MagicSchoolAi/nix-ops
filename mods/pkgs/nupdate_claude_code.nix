# Update script for claude-code-latest package
# Checks npm registry for new versions and updates the nix derivation
{ pkgs, pog, ... }:
let
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
  sed = "${pkgs.gnused}/bin/sed";
  nix-prefetch-url = "${pkgs.nix}/bin/nix-prefetch-url";
in
pog {
  name = "nupdate_claude_code";
  description = "Check and update claude-code-latest to the latest npm version";
  script = helpers: with helpers; ''
    NPM_REGISTRY_URL="https://registry.npmjs.org"
    PACKAGE_NAME="@anthropic-ai/claude-code"
    PACKAGE_NIX="mods/pkgs/claude-code-latest.nix"

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
      local tarball_url="$NPM_REGISTRY_URL/$PACKAGE_NAME/-/claude-code-$version.tgz"
      ${nix-prefetch-url} "$tarball_url" 2>/dev/null | tail -1
    }

    current_version=$(get_current_version)
    latest_version=$(get_latest_version)

    green "Current version: $current_version"
    green "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
      green "claude-code-latest is already up to date!"
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

    # Update hash in the nix file
    ${sed} -i "s/sha256 = \"[^\"]*\"/sha256 = \"$new_hash\"/" "$PACKAGE_NIX"

    green "Updated $PACKAGE_NIX to version $latest_version"

    # Show what changed
    echo ""
    green "Changes made:"
    git diff --stat "$PACKAGE_NIX" 2>/dev/null || true
  '';
}
