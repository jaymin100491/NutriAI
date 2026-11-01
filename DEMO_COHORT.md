# Demo cohort workspace (illustrative — not clinical research)

This feature seeds **55 multi-persona users** so stakeholder demos look like a lived-in product:

- Different goals (cholesterol, diabetes, BP, weight, energy, vitamin D, inflammation, …)
- Longitudinal labs + biometrics (about **1–8 months**, many **120+ days**)
- Outcome arcs: **improved / mixed / flat / adjusted / early**
- **Meal substitution** stories (dislike / unfamiliar ingredient → swap)
- **Retest-ready** users with a **sample Labcorp-style wellness lab order** page

## Framing for the room

Say: *“Illustrative multi-persona workspace to show product depth.”*  
Do **not** say: *“clinical study”*, *“IRB research”*, or *“we proved Labcorp order lift.”*

## Credentials

| Role | Login |
|------|--------|
| Admin | `admin@nutriai.app` / `admin123` |
| Seeded hero demo | `jaymin@nutriai.app` / `demo` |
| Any cohort persona | `{slug}@cohort.nutriai.app` / `demo` |

Examples:
- `c02@cohort.nutriai.app` — improved lipids + weight, **retest ready**, meal swap
- `c11@cohort.nutriai.app` — diabetes arc **flat** (honest non-improvement)
- `c55@cohort.nutriai.app` — multi-goal **improved**, retest ready, meal swap

## Where to click in the app

1. Sign in as **admin**
2. Profile → **Demo cohort (55 personas)**
3. Filter by arc or **Retest only**
4. Open **Lab order** on a retest-ready user (sample requisition layout)
5. Or sign in as a cohort user → Profile → **Sample Labcorp-style lab order**

## API

- `GET /api/v1/admin/cohort`
- `POST /api/v1/admin/cohort/seed?force=false|true`
- `GET /api/v1/admin/users/{id}/lab-order`
- `GET /api/v1/lab-results/sample-lab-order` (current user)

## Config

```bash
DEMO_MODE=true
SEED_DEMO_COHORT=true
```

First API startup seeds the cohort (idempotent). Force refresh:

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/admin/cohort/seed?force=true" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Deploy note

Seeding 55 users with history can take **1–3 minutes** on first boot. Keep `SEED_DEMO_COHORT=true` for the live demo host; set `false` if you want a clean production tenant later.

## Live AI meal generation (new users during demo)

Cohort history uses the offline catalog for speed. **New / live users** regenerate plans with the **live AI chef** when you set:

```bash
OPENAI_API_KEY=sk-...
# or ANTHROPIC_API_KEY=...
AI_MEAL_GENERATION=true
```

Then Profile → Dietary Preferences → e.g. Vegetarian + Mexican (or any typed cuisine) → Save & regenerate. Plans are not limited to a fixed menu.
