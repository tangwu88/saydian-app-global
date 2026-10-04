#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
store_path="$repo_root/android/app/saydian-global-play-upload.p12"
properties_path="$repo_root/android/play-upload.properties"

if [[ -e "$store_path" || -e "$properties_path" ]]; then
  echo "An upload key or signing properties already exist; refusing to replace them." >&2
  exit 1
fi

umask 077
SAYDIAN_UPLOAD_STOREPASS="$(openssl rand -hex 32)"
export SAYDIAN_UPLOAD_STOREPASS
keytool -genkeypair \
  -alias saydian_global_play_upload \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storetype PKCS12 \
  -dname "CN=SAYDIAN Health Android upload key" \
  -keystore "$store_path" \
  -storepass:env SAYDIAN_UPLOAD_STOREPASS \
  -keypass:env SAYDIAN_UPLOAD_STOREPASS \
  -noprompt

printf 'storeFile=saydian-global-play-upload.p12\nstorePassword=%s\nkeyAlias=saydian_global_play_upload\nkeyPassword=%s\n' \
  "$SAYDIAN_UPLOAD_STOREPASS" "$SAYDIAN_UPLOAD_STOREPASS" > "$properties_path"
chmod 600 "$store_path" "$properties_path"
keytool -list -v \
  -alias saydian_global_play_upload \
  -keystore "$store_path" \
  -storepass:env SAYDIAN_UPLOAD_STOREPASS \
  | sed -n '/SHA256:/p'
unset SAYDIAN_UPLOAD_STOREPASS

echo "Local Play upload key created. Back up the ignored keystore and play-upload.properties securely before registering the upload certificate."
