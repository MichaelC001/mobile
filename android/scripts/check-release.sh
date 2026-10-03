#!/usr/bin/env bash
set -euo pipefail

APK="${1:?Usage: scripts/check-release.sh <release-apk>}"
APKANALYZER="${ANDROID_HOME:?Set ANDROID_HOME to your Android SDK}/cmdline-tools/latest/bin/apkanalyzer"

if [[ "$("$APKANALYZER" manifest debuggable "$APK")" != "false" ]]; then
  echo "Error: Expected a non-debuggable release APK." >&2
  exit 1
fi

for registrar in \
  com.google.mlkit.common.internal.CommonComponentRegistrar \
  com.google.mlkit.vision.common.internal.VisionCommonRegistrar; do
  echo "Checking release constructor: $registrar"
  "$APKANALYZER" dex code --class "$registrar" --method '<init>()V' "$APK" \
    | grep -Fq '.method public constructor <init>()V'
done

echo "Release component registrar checks passed"
