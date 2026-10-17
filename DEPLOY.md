# NutriAI production / live demo deploy

Shareable HTTPS app (Firebase Hosting) + hosted API. Audience opens one link on phone or laptop — no local database setup.

## Architecture

| Piece | Where | Notes |
|-------|--------|------|
| Flutter web UI | **Firebase Hosting** | Shareable `*.web.app` URL |
| FastAPI + DB | Cloud Run / Render / Railway | SQLite OK for early demo; Postgres for production |
| Secrets | Host env vars | Never commit `.env` |

## Audience flow

1. Open the Firebase URL  
2. **Sign up** (or seeded demo `jaymin@nutriai.app` / `demo`)  
3. **Upload lab PDF** or **paste** markers from MyChart / Labcorp / employer portal  
4. NutriAI stores labs, builds Mon–Sun plan (~1 minute)  
5. Track biometrics daily; **Friday** prepares next week’s plan  
6. Admin: `admin@nutriai.app` (change password after first deploy)

## 1) Deploy API

Example with Render / Railway / Cloud Run:

- Root / Docker: `nutriai-backend/`
- Env (minimum):

```bash
DEMO_MODE=true          # set false once you no longer want seeded demo user
DEBUG=false
ENVIRONMENT=production
SECRET_KEY=<openssl rand -hex 32>
DATABASE_URL=sqlite:///./nutriai.db   # or postgres://... for production
ALLOWED_ORIGINS=https://YOUR-PROJECT.web.app,https://YOUR-PROJECT.firebaseapp.com
OPENAI_API_KEY=         # optional
ANTHROPIC_API_KEY=      # optional
```

On first boot: tables created, admin user ensured (`admin@nutriai.app`), optional demo seed if `DEMO_MODE=true`.

**Immediately after first deploy:** log in as admin and change the password (default `admin123` is for bootstrap only).

Copy the public API URL, e.g. `https://nutriai-api.example.com`

## 2) Firebase Hosting (Flutter web)

```bash
cd nutriai_mobile
firebase login
firebase use YOUR_FIREBASE_PROJECT_ID

export NUTRIAI_API_BASE_URL=https://YOUR-API-HOST
chmod +x scripts/deploy-firebase.sh
./scripts/deploy-firebase.sh
```

Share the Hosting URL from the Firebase console.

## 3) CORS

With `DEBUG=false`, set `ALLOWED_ORIGINS` to your Firebase URL(s) only.

## 4) Production hardening checklist

- [ ] Strong `SECRET_KEY`  
- [ ] `DEBUG=false`, `ENVIRONMENT=production`  
- [ ] Change admin password (or disable default admin)  
- [ ] Postgres instead of SQLite for multi-instance / durability  
- [ ] HTTPS only; Firebase URL in CORS  
- [ ] Optional: rotate demo credentials or set `DEMO_MODE=false`  
- [ ] Optional AI keys for free-text goal interpretation  

## Local dry-run (before Firebase)

```bash
# terminal 1
cd nutriai-backend && ./scripts/run-api.sh

# terminal 2
cd nutriai_mobile
flutter run -d chrome --web-port 8080 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=DEMO_MODE=true
```

Sign up → upload PDF or paste sample panel → confirm plan + history + tracking.
