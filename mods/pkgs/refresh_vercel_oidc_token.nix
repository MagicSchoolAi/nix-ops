{ pkgs, vercel ? pkgs.vercel-cli, pog, ... }:
let
  _vercel = "${vercel}/bin/vercel";
  jq = "${pkgs.jq}/bin/jq";
  base64 = "${pkgs.toybox}/bin/base64";
  cut = "${pkgs.toybox}/bin/cut";
in
pog {
  name = "refresh_vercel_oidc_token";
  description = "Refresh the Vercel OIDC token.";
  flags = [{ name = "force"; description = "Remove existing and pull fresh token"; bool = true; }];
  beforeExit = ''
    debug "Cleaning up..."
    rm -f /tmp/foo.env
  '';
  script = helpers: with helpers; ''
    is_token_valid() {
        token="$1"
        exp=$(echo "$token" | ${cut} -d '.' -f2 | ${base64} -d | ${jq} -r '.exp')
        current_time=$(date +%s)
        one_hour_from_now=$((current_time + 3600))

        if [ -z "$exp" ]; then
            echo "Could not decode token or expiration time not found."
            return 1
        fi

        if [ "$current_time" -ge "$exp" ]; then
            echo "Token is expired."
            return 1
        elif [ "$exp" -le "$one_hour_from_now" ]; then
            echo "Token is invalid (expires within an hour)."
            return 1
        else
            echo "Token is valid."
            return 0
        fi
    }

    fetch_new_token() {
        echo "Checking Vercel login status... (If no user is found, choose Github during signin)"
        ${_vercel} whoami

        echo "Running 'vercel link'..."
        if ${_vercel} link -S magicschoolai -p magicschoolai --yes; then
            echo "'vercel link' completed successfully."
        else
            die "'vercel link' failed." 1
        fi

        echo "Pulling environment variables into '/tmp/foo.env'..."
        ${_vercel} env pull /tmp/foo.env
        VERCEL_OIDC_TOKEN=$(grep "VERCEL_OIDC_TOKEN" /tmp/foo.env | cut -d '=' -f2)
        if [ -n "$VERCEL_OIDC_TOKEN" ]; then
            echo "VERCEL_OIDC_TOKEN found: $VERCEL_OIDC_TOKEN"
            # save the token to a file
            echo "export VERCEL_OIDC_TOKEN=\"$VERCEL_OIDC_TOKEN\"" > ./.vercel_oidc_token
        else
            die "VERCEL_OIDC_TOKEN not found in foo.env" 1
        fi
    }

    if ${flag "force"}; then
        echo "Forcing token refresh..."
        fetch_new_token
        exit 0
    fi

    echo "Checking Vercel OIDC token..."
    if [[ -f ./.vercel_oidc_token ]]; then
        echo "Found existing token file."
        VERCEL_OIDC_TOKEN="$(cut -d '=' -f 2 .vercel_oidc_token)"
        if is_token_valid "$VERCEL_OIDC_TOKEN"; then
            echo "Using existing valid token."
            exit 0
        fi
    fi
    echo "No token found."
    fetch_new_token
  '';
}
