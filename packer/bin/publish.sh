#!/usr/bin/env bash
# Uploads a box to GitHub Releases and adds it to the Vagrant catalog.
#
#   REPO=owner/repo BOX_NAME=owner/ubuntu bin/publish.sh <box-file> <version> <arch>
#
# Each version gets one release (ubuntu-<version>) holding that version's boxes, one per
# architecture. A single catalog (ubuntu.json) in the fixed release `ubuntu-catalog` lists
# every version and architecture, so its URL never changes:
#
#   https://github.com/<repo>/releases/download/ubuntu-catalog/ubuntu.json
#
# Each architecture is built and published from its own host, so the catalog is merged,
# never overwritten. Publishing the same version and architecture again replaces it.
set -euo pipefail

box=${1:?box file}
version=${2:?version}
arch=${3:?arch}
: "${REPO:?owner/repo that hosts the releases}"
: "${BOX_NAME:?Vagrant box name, e.g. owner/ubuntu}"

tag="ubuntu-$version"
catalog_tag="ubuntu-catalog"
catalog_file="ubuntu.json"
asset=$(basename "$box")
url="https://github.com/$REPO/releases/download/$tag/$asset"
max_bytes=$((2 * 1024 ** 3)) # GitHub release asset size limit

size=$(wc -c < "$box" | tr -d ' ')
if (( size > max_bytes )); then
  echo "ERROR: $asset is $size bytes; GitHub release assets are limited to 2 GiB" >&2
  exit 1
fi

if command -v sha256sum >/dev/null; then
  checksum=$(sha256sum "$box" | cut -d' ' -f1)
else
  checksum=$(shasum -a 256 "$box" | cut -d' ' -f1)
fi

ensure_release() { # tag title notes
  gh release view "$1" --repo "$REPO" >/dev/null 2>&1 ||
    gh release create "$1" --repo "$REPO" --title "$2" --notes "$3"
}

ensure_release "$tag" "Ubuntu $version box" "Ubuntu Server $version Vagrant box for VirtualBox (amd64 and arm64)."
gh release upload "$tag" "$box" --repo "$REPO" --clobber

ensure_release "$catalog_tag" "Vagrant box catalog" "Vagrant box metadata (ubuntu.json); the boxes are in the ubuntu-<version> releases."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Only start from an empty catalog when none exists yet: a failed download of an existing
# one must stop here, not replace it with a catalog that lacks the other entries.
if gh release view "$catalog_tag" --repo "$REPO" --json assets -q '.assets[].name' | grep -qx "$catalog_file"; then
  gh release download "$catalog_tag" --repo "$REPO" -p "$catalog_file" -D "$work"
else
  echo '{}' > "$work/$catalog_file"
fi

# Replace this version+architecture's provider entry, keep everything else.
# amd64 is the default architecture, matching what Vagrant assumes for boxes that don't say.
jq --arg name "$BOX_NAME" --arg version "$version" --arg arch "$arch" \
   --arg url "$url" --arg checksum "$checksum" '
  {name: $name, provider: {
     name: "virtualbox", architecture: $arch, default_architecture: ($arch == "amd64"),
     url: $url, checksum_type: "sha256", checksum: $checksum}} as $new
  | (.versions // []) as $versions
  | {name: $new.name,
     versions: (
       ($versions | map(select(.version != $version))) +
       [{version: $version,
         providers: ((($versions | map(select(.version == $version)) | first // {providers: []}).providers
                       | map(select(.architecture != $arch))) + [$new.provider])}]
       | sort_by(.version | split(".") | map(tonumber)))}
' "$work/$catalog_file" > "$work/new.json"

mv "$work/new.json" "$work/$catalog_file"
gh release upload "$catalog_tag" "$work/$catalog_file" --repo "$REPO" --clobber

echo "Published $BOX_NAME $version ($arch): $url"
echo "Catalog: https://github.com/$REPO/releases/download/$catalog_tag/$catalog_file"
