# NutriAI

AI-powered personalized nutrition coaching from lab results.

Open-market demo: sign up → paste lab markers (or use seeded demo) → personalized meal plans → progress → Labcorp-only retest scheduling.

## Projects

| Folder | Stack | Purpose |
|--------|--------|---------|
| `nutriai-backend/` | FastAPI + SQLite | API, diet engine, goals, tracking, lab paste/seed |
| `nutriai_mobile/` | Flutter (web/mobile) | Patient-facing UI (Firebase Hosting ready) |

## Quick start (local)

### Backend

```bash
cd nutriai-backend
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
./scripts/run-api.sh
```

API docs: http://127.0.0.1:8000/api/docs  
Demo login: `jaymin@nutriai.app` / `demo`

Database: created automatically as `nutriai.db` on startup (`DEMO_MODE=true` seeds sample data). No manual SQL.

### Flutter web

```bash
cd nutriai_mobile
flutter pub get
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEMO_MODE=true
```

## Live multi-device demo (Firebase)

See [DEPLOY.md](./DEPLOY.md). Short version:

1. Host the API once (Cloud Run / Render / Railway) with `DEMO_MODE=true`  
2. Deploy Flutter web to **Firebase Hosting** via `nutriai_mobile/scripts/deploy-firebase.sh`  
3. Share the Firebase URL — attendees open on phone/laptop; **they do not create a database**

## Audience flow

1. Sign up **or** try seeded demo  
2. Paste a few markers from MyChart / Labcorp / employer portal (stored in NutriAI DB)  
3. Goals → plans → progress → retest  
4. Roadmap pitch: automatic multi-system lab fetch (no paste)

## Environment

Copy `nutriai-backend/.env.example` → `.env`. Do not commit secrets.

Optional AI chat keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`
