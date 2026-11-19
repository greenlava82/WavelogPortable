#!/usr/bin/env bash
# Copies the Play upload key and the Play service account into GitHub
# secrets for the "Release to Google Play" workflow. Run it yourself, from
# the repo folder; nothing is printed.
#
#   tool/set_play_secrets.sh path/to/play-service-account.json
#
# Reads the upload key from android/key.properties (the same file local
# release builds use). Needs the gh CLI, signed in with access to the repo.
set -euo pipefail

json="${1:-}"
props="android/key.properties"
[ -f "$props" ] || { echo "Missing $props (run from the repo folder)"; exit 1; }
[ -n "$json" ] && [ -f "$json" ] || { echo "Usage: $0 path/to/play-service-account.json"; exit 1; }

get() { grep -E "^$1=" "$props" | head -1 | cut -d= -f2-; }

store="$(get storeFile)"
case "$store" in /*) ;; *) store="android/app/$store" ;; esac
[ -f "$store" ] || { echo "Keystore not found at the storeFile path in $props"; exit 1; }

base64 < "$store" | tr -d '\n' | gh secret set ANDROID_KEYSTORE_BASE64
get storePassword | tr -d '\n' | gh secret set ANDROID_KEYSTORE_PASSWORD
get keyAlias      | tr -d '\n' | gh secret set ANDROID_KEY_ALIAS
get keyPassword   | tr -d '\n' | gh secret set ANDROID_KEY_PASSWORD
gh secret set PLAY_SERVICE_ACCOUNT_JSON < "$json"

echo "Done. Secrets now set:"
gh secret list
