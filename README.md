# NutriAI

AI-powered personalized nutrition coaching from lab results.

Open-market demo app: import health/lab history → goals → personalized meal plans → biometric progress → Labcorp-only retest scheduling.

## Projects

| Folder | Stack | Purpose |
|--------|--------|---------|
| `nutriai-backend/` | FastAPI + SQLite/Postgres | API, diet engine, goals, tracking, lab seed |
| `nutriai_mobile/` | Flutter (web/mobile) | Patient-facing UI |

## Quick start (local demo)

### Backend

```bash
cd nutriai-backend
cp .env.example .env
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
./scripts/run-api.sh
```

API: http://127.0.0.1:8000/api/docs

Demo login: `jaymin@nutriai.app` / `demo` (when `DEMO_MODE=true`)

### Flutter web

```bash
cd nutriai_mobile
flutter pub get
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEMO_MODE=true
```

## Environment

Copy `nutriai-backend/.env.example` → `.env`. Never commit `.env`.

Optional for richer AI chat:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`

## Demo flow

1. Sign in with demo account  
2. Review multi-year lab timeline  
3. Goals → Add any goal → plan regenerates  
4. Dietary Preferences → veg / cuisine / dislikes  
5. Progress → biometric improvement journey  
6. Retest → schedule follow-up (Labcorp fulfillment)

## Notes

- Meal plans are rule + catalog driven (work without AI keys).  
- AI keys improve conversational coaching.  
- Local SQLite stores labs, plans, goals, and biometrics.
