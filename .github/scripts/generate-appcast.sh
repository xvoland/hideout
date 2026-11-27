#!/bin/bash
# Generate (and Ed25519-sign) the Sparkle appcast for a new release.
# Usage: generate-appcast.sh <tag> <Hideout.app.zip> <appcast.xml>
#
# SPARKLE_PRIVATE_KEY must contain the private key exported with
# `Sparkle/bin/generate_keys -x`. It is read from stdin by Sparkle's tools,
# never written to disk in CI.
set -euo pipefail

TAG="${1:?Usage: $0 <tag> <zip> <appcast>}"
ZIP="${2:?Usage: $0 <tag> <zip> <appcast>}"
OUTPUT="${3:?Usage: $0 <tag> <zip> <appcast>}"

: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY secret is required}"
# Actions secrets may carry a trailing newline; Sparkle wants the bare key.
KEY=$(printf '%s' "${SPARKLE_PRIVATE_KEY}" | tr -d '[:space:]')

SPARKLE_VERSION="2.10.1"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -fsSL \
  "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
  -o "${TMP}/Sparkle.tar.xz"
tar -xJf "${TMP}/Sparkle.tar.xz" -C "${TMP}"
BIN="${TMP}/bin"

UPDATES="${TMP}/updates"
mkdir -p "${UPDATES}"
cp "${ZIP}" "${UPDATES}/Hideout.app.zip"
# Keep previous items in the feed so older installs can update too.
if [[ -f "${OUTPUT}" ]]; then
  cp "${OUTPUT}" "${UPDATES}/appcast.xml"
fi

printf '%s\n' "${KEY}" | \
  "${BIN}/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "https://github.com/xvoland/hideout/releases/download/${TAG}/" \
    --link "https://github.com/xvoland/hideout" \
    "${UPDATES}"

SIGNATURE=$(printf '%s' "${KEY}" | \
  "${BIN}/sign_update" -p --ed-key-file - "${UPDATES}/Hideout.app.zip")
LENGTH=$(stat -f%z "${UPDATES}/Hideout.app.zip")

python3 - "${UPDATES}/appcast.xml" "${SIGNATURE}" "${LENGTH}" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, signature, length = sys.argv[1], sys.argv[2], sys.argv[3]
ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", ns)
tree = ET.parse(path)

# The newest item is the one pointing at this release's archive.
items = tree.getroot().findall("./channel/item")
if not items:
    raise SystemExit("appcast has no items")
enclosure = items[0].find("enclosure")
if enclosure is None:
    raise SystemExit("newest appcast item has no enclosure")
enclosure.set(f"{{{ns}}}edSignature", signature)
enclosure.set("length", length)
tree.write(path, encoding="utf-8", xml_declaration=True)
PY

cp "${UPDATES}/appcast.xml" "${OUTPUT}"
echo "Wrote signed appcast to ${OUTPUT} for ${TAG}"
