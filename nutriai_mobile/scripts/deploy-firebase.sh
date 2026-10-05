#!/usr/bin/env bash
# Build Flutter web and deploy to Firebase Hosting.
# Usage:
#   export NUTRIAI_API_BASE_URL=https://YOUR-API-HOST
#   ./scripts/deploy-firebase.sh
set -euo pipefail
cd "$(dirname "$0")/.."

API_URL="${NUTRIAI_API_BASE_URL:-}"
if [ -z "$API_URL" ]; then
  echo "Set NUTRIAI_API_BASE_URL to your public FastAPI URL first."
  echo "Example: export NUTRIAI_API_BASE_URL=https://nutriai-api.onrender.com"
  exit 1
fi

if grep -q 'YOUR_FIREBASE_PROJECT_ID' .firebaserc; then
  echo "Replace YOUR_FIREBASE_PROJECT_ID in .firebaserc with your Firebase project id,"
  echo "then run: firebase login && firebase use YOUR_PROJECT_ID"
  exit 1
fi

flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL="$API_URL" \
  --dart-define=DEMO_MODE=true

firebase deploy --only hosting
echo "Done. Open your Firebase Hosting URL and share it for the live demo."
