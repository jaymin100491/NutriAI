#!/usr/bin/env bash
# Run NutriAI backend API (requires VPN for live Labcorp QA sync)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  .venv/bin/pip install -r requirements.txt
fi

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example — review before production use"
fi

.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
