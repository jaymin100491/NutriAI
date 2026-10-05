#!/usr/bin/env bash
# Run NutriAI Flutter web on patient-local.labcorp.com:4200 with TLS (Okta QA redirect)
set -euo pipefail
cd "$(dirname "$0")/.."

CERT="certs/patient-local.pem"
KEY="certs/patient-local-key.pem"

if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
  echo "Missing TLS certs. Run:"
  echo "  mkdir -p certs"
  echo "  mkcert -cert-file certs/patient-local.pem -key-file certs/patient-local-key.pem patient-local.labcorp.com localhost 127.0.0.1"
  exit 1
fi

echo "Ensure /etc/hosts contains: 127.0.0.1 patient-local.labcorp.com"
echo "Ensure NutriAI backend is running on :8000"
echo "Ensure LabCorp VPN is connected for live lab sync"
echo ""

flutter run -d chrome \
  --web-hostname patient-local.labcorp.com \
  --web-port 4200 \
  --web-tls-cert-path "$CERT" \
  --web-tls-cert-key-path "$KEY" \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=LABCORP_PORTAL_API_URL=https://portal-api.patient-qa.dev.cws.labcorp.com
