# NutriAI

AI-powered personalized nutrition coaching from lab results.

**Production flow:** sign up → upload lab PDF or paste markers → Mon–Sun diet plan in about a minute → daily biometrics → next week’s plan prepared every Friday → past-plan history → admin panel.

## Projects

| Folder | Stack | Purpose |
|--------|--------|---------|
| `nutriai-backend/` | FastAPI + SQLite (Postgres-ready) | API, PDF/paste labs, weekly plans, tracking, admin |
| `nutriai_mobile/` | Flutter (web/mobile) | Patient UI + admin panel (Firebase Hosting ready) |

## Quick start (local)

### Backend

```bash
cd nutriai-backend
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
./scripts/run-api.sh
```

- API docs: http://127.0.0.1:8000/api/docs  
- Seeded demo: `jaymin@nutriai.app` / `demo`  
- Admin: `admin@nutriai.app` / `admin123` (**change in production**)

Database: created automatically as `nutriai.db` on startup (`DEMO_MODE=true` seeds sample data).

### Flutter web

```bash
cd nutriai_mobile
flutter pub get
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEMO_MODE=true
```

App: http://localhost:8080

## Product capabilities

1. **Signup + labs** — upload PDF or paste MyChart / Labcorp / portal markers; results are stored  
2. **Fast plan** — goals derived from labs; professional Mon–Sun meal plan generated immediately  
3. **Daily biometrics** — weight, glucose, sleep, mood, etc.  
4. **Friday release** — next Mon–Sun week is prepared from biometrics + goals  
5. **History** — past plans kept for improvement review  
6. **Admin** — manage all users, labs, plans, tracking; regenerate weeks  

## Live multi-device deploy (Firebase + hosted API)

See [DEPLOY.md](./DEPLOY.md). Short version:

1. Host the API (Cloud Run / Render / Railway) with a strong `SECRET_KEY`  
2. Deploy Flutter web to Firebase Hosting  
3. Set `ALLOWED_ORIGINS` to your Firebase URL; turn `DEBUG=false`  
4. Change admin password; prefer Postgres for production traffic  

## Environment

Copy `nutriai-backend/.env.example` → `.env`. Do not commit secrets.

Optional AI keys (goal interpretation / chat): `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`
