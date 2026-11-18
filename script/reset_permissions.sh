#!/usr/bin/env bash
# Reset macOS TCC Accessibility and ScreenCapture permissions for NewNet
set -euo pipefail

BUNDLE_ID="${1:-NihanviBuilds.NewNet}"

echo "Resetting TCC Accessibility permissions for ${BUNDLE_ID}..."
tccutil reset Accessibility "${BUNDLE_ID}" || true

echo "Resetting TCC ScreenCapture permissions for ${BUNDLE_ID}..."
tccutil reset ScreenCapture "${BUNDLE_ID}" || true

echo "Permissions for ${BUNDLE_ID} have been reset."
