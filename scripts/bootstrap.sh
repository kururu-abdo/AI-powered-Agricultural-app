#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Install the Flutter stable SDK first.'; exit 1; }
if [[ -d android || -d ios ]]; then
  echo 'Native project already exists. Run flutter pub get instead.'
  exit 1
fi
# Generate native wrappers in a temporary project; preserve all authored files.
agri_temp_dir="$(mktemp -d)"
trap 'rm -rf "$agri_temp_dir"' EXIT
flutter create --platforms=android,ios --org "${1:-com.example}" \
  --project-name agri_intelligence --no-pub "$agri_temp_dir/agri_intelligence"
cp -R "$agri_temp_dir/agri_intelligence/android" ./android
cp -R "$agri_temp_dir/agri_intelligence/ios" ./ios
cp "$agri_temp_dir/agri_intelligence/.metadata" ./.metadata
flutter pub get
echo 'Native projects created. Run flutter run for the local preview.'
