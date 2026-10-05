# NutriAI live demo deploy (Firebase Hosting + hosted API)

Yes — deploying looks much better for a manager / org-lead demo: one HTTPS link
works on phones and laptops. Nobody creates a database on their device.

## Architecture

| Piece | Where | Notes |
|-------|--------|------|
| Flutter web UI | **Firebase Hosting** (your account) | Shareable `*.web.app` URL |
| FastAPI + SQLite DB | Cloud Run / Render / Railway | Creates DB + seeds on startup |
| Secrets | Host env vars | Never commit `.env` |

Firebase Hosting serves the app. The API (and SQLite) live on a small backend host.
Same Google account can use **Cloud Run** for the API if you prefer staying in GCP.

## Audience flow

1. Open the Firebase URL on phone or laptop  
2. **Sign up** (or try seeded demo `jaymin@nutriai.app` / `demo`)  
3. **Paste** a few lab markers from MyChart / Labcorp / employer portal  
4. NutriAI stores them in the shared database and unlocks coaching  
5. Pitch: *“Today copy-paste; next we integrate systems to fetch automatically.”*

## 1) Deploy API (required once)

Example with Render/Railway/Cloud Run:

- Root / Docker: `nutriai-backend/`
- Env:
  - `DEMO_MODE=true`
  - `DATABASE_URL=sqlite:///./nutriai.db` (fine for demo)
  - `SECRET_KEY=<random>`
  - `DEBUG=false`
  - Optional: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`
- On first boot, tables are created and the Jaymin demo workspace is seeded.

Copy the public API URL, e.g. `https://nutriai-api.example.com`

## 2) Firebase Hosting (Flutter web)

```bash
cd nutriai_mobile
firebase login
# create or select a project in console.firebase.google.com
firebase use YOUR_FIREBASE_PROJECT_ID
# edit .firebaserc → set "default" to that project id

export NUTRIAI_API_BASE_URL=https://YOUR-API-HOST
chmod +x scripts/deploy-firebase.sh
./scripts/deploy-firebase.sh
```

Share the Hosting URL from the Firebase console.

## 3) CORS

Backend already allows all origins when `DEBUG=true`. For production, set
`ALLOWED_ORIGINS` to your Firebase URL in backend config/env.

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

Sign up → paste sample panel → confirm labs appear.
