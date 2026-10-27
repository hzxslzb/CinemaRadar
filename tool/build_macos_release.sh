#!/bin/zsh

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
project_root="$(cd -- "${script_dir:?}/.." && pwd)"
app_source="${project_root:?}/build/macos/Build/Products/Release/CinemaRadar.app"
release_version="$(awk '/^version:/ { print $2; exit }' "${project_root:?}/pubspec.yaml")"
[[ "${release_version:?}" =~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' ]]
artifact_target="${project_root:?}/build/macos/CinemaRadar-${release_version}.zip"

[ -f "${project_root:?}/pubspec.yaml" ]
grep -q '^name: cinema_radar$' "${project_root:?}/pubspec.yaml"
case "${artifact_target:?}" in
  "${project_root:?}"/build/macos/CinemaRadar-${release_version}.zip) ;;
  *) print -u2 "Unexpected artifact target: $artifact_target"; exit 2 ;;
esac

cd -- "$project_root"
FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}" \
  flutter build macos --release

[ -d "${app_source:?}" ]
artifact_temp="$(mktemp "${project_root:?}/build/macos/CinemaRadar.XXXXXX.zip")"
case "${artifact_temp:?}" in
  "${project_root:?}"/build/macos/CinemaRadar.*.zip) ;;
  *) print -u2 "Unexpected temporary artifact: $artifact_temp"; exit 3 ;;
esac

cleanup() {
  if [ -n "${artifact_temp:-}" ] && [ -f "$artifact_temp" ]; then
    rm -f -- "$artifact_temp"
  fi
}
trap cleanup EXIT

ditto -c -k --sequesterRsrc --keepParent "$app_source" "$artifact_temp"
[ -s "${artifact_temp:?}" ]
mv -f -- "$artifact_temp" "$artifact_target"
artifact_temp=""

print "Created $artifact_target"
