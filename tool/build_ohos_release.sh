#!/bin/zsh

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
project_root="$(cd -- "${script_dir:?}/.." && pwd)"
profile="${project_root:?}/ohos/build-profile.json5"
signing_file="${CINEMA_RADAR_OHOS_SIGNING_CONFIG:-${project_root:?}/ohos/build-profile.local.json5}"
artifact_dir="${project_root:?}/build/ohos"
release_version="$(awk '/^version:/ { print $2; exit }' "${project_root:?}/pubspec.yaml")"
[[ "${release_version:?}" =~ '^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' ]]
artifact_target="${artifact_dir:?}/CinemaRadar-${release_version}.hap"

[ -f "${project_root:?}/pubspec.yaml" ]
grep -q '^name: cinema_radar$' "${project_root:?}/pubspec.yaml"
[ -f "${profile:?}" ]
[ ! -L "${profile:?}" ]
[ -f "${signing_file:?}" ]
[ ! -L "${signing_file:?}" ]
case "${artifact_target:?}" in
  "${project_root:?}"/build/ohos/CinemaRadar-${release_version}.hap) ;;
  *) print -u2 "Unexpected artifact target: $artifact_target"; exit 2 ;;
esac

temporary_dir="$(mktemp -d /tmp/CinemaRadar-ohos.XXXXXX)"
case "${temporary_dir:?}" in
  /tmp/CinemaRadar-ohos.*|/private/tmp/CinemaRadar-ohos.*) ;;
  *) print -u2 "Unexpected temporary directory: $temporary_dir"; exit 3 ;;
esac
profile_backup="${temporary_dir:?}/build-profile.json5"
cp -p -- "$profile" "$profile_backup"

cleanup() {
  if [ -f "${profile_backup:-}" ]; then
    cp -p -- "$profile_backup" "$profile"
    rm -f -- "$profile_backup"
  fi
  if [ -d "${temporary_dir:-}" ] && [ ! -L "${temporary_dir:-}" ]; then
    rmdir -- "$temporary_dir"
  fi
}
trap cleanup EXIT INT TERM

node "${script_dir:?}/merge_ohos_signing.mjs" \
  "$profile_backup" "$signing_file" "$profile"

cd -- "$project_root"
PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}" \
FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}" \
  flutter build hap --release --no-pub

hap_candidates=("${project_root:?}"/ohos/entry/build/default/outputs/default/*-signed.hap(N))
if (( ${#hap_candidates[@]} != 1 )); then
  print -u2 "Expected exactly one signed HAP, found ${#hap_candidates[@]}."
  exit 4
fi
signed_hap="${hap_candidates[1]}"
[ -f "${signed_hap:?}" ]
[ ! -L "${signed_hap:?}" ]

mkdir -p -- "$artifact_dir"
cp -f -- "$signed_hap" "$artifact_target"
print "Created $artifact_target"
shasum -a 256 "$artifact_target"
