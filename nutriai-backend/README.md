# NutriAI Backend API

AI-Powered Personalized Dietitian Application - FastAPI Backend

## Features

- 🔐 JWT Authentication
- 👤 User Profile Management
- 🧪 Lab Results Integration
- 🍽️ Diet Plan Generation
- 📊 Daily Health Tracking
- 🥗 Recipe Management
- 📈 Progress Analytics

## Tech Stack

- **Framework:** FastAPI 0.109.0
- **Python:** 3.11+
- **Authentication:** JWT (python-jose)
- **Database:** PostgreSQL (SQLAlchemy) - Currently using mock data
- **AI:** Anthropic Claude / OpenAI GPT (for future integration)

## Quick Start

### Prerequisites

- Python 3.11 or higher
- pip

### Installation

1. Clone the repository:
```bash
cd nutriai-backend
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Create `.env` file:
```bash
cp .env.example .env
```

5. Run the application:
```bash
python -m app.main
```

Or using uvicorn directly:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at:
- API: http://localhost:8000
- Docs: http://localhost:8000/api/docs
- ReDoc: http://localhost:8000/api/redoc

## API Endpoints

### Authentication
- `POST /api/v1/auth/login` - Login and get JWT tokens
- `POST /api/v1/auth/refresh` - Refresh access token

### Users
- `GET /api/v1/users/profile` - Get user profile
- `PUT /api/v1/users/profile` - Update user profile
- `GET /api/v1/users/me` - Get current user info

### Lab Results
- `GET /api/v1/lab-results` - Get all lab results
- `GET /api/v1/lab-results/latest` - Get latest lab result
- `GET /api/v1/lab-results/{id}` - Get specific lab result

### Diet Plans
- `GET /api/v1/diet-plans/current` - Get current diet plan
- `POST /api/v1/diet-plans/generate` - Generate new diet plan
- `GET /api/v1/diet-plans/{id}` - Get specific diet plan

### Recipes
- `GET /api/v1/recipes` - List recipes (with filters)
- `GET /api/v1/recipes/{id}` - Get recipe detail
- `GET /api/v1/recipes/search/{query}` - Search recipes

### Tracking
- `POST /api/v1/tracking/daily` - Add daily tracking
- `GET /api/v1/tracking/daily` - Get tracking history
- `GET /api/v1/tracking/progress` - Get progress data

## Demo Users

For testing, use these credentials:

```json
{
  "email": "john.doe@example.com",
  "password": "any_password"
}
```

```json
{
  "email": "sarah.smith@example.com",
  "password": "any_password"
}
```

```json
{
  "email": "mike.johnson@example.com",
  "password": "any_password"
}
```

## Project Structure

```
nutriai-backend/
├── app/
│   ├── api/
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── auth.py
│   │       │   ├── users.py
│   │       │   ├── lab_results.py
│   │       │   ├── diet_plans.py
│   │       │   ├── tracking.py
│   │       │   └── recipes.py
│   │       └── router.py
│   ├── core/
│   │   ├── config.py
│   │   └── security.py
│   ├── db/
│   │   └── mock_data.py
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── user.py
│   │   ├── lab_result.py
│   │   ├── diet_plan.py
│   │   ├── recipe.py
│   │   └── tracking.py
│   └── main.py
├── requirements.txt
├── .env.example
└── README.md
```

## Development

### Running Tests
```bash
pytest
```

### Code Formatting
```bash
black app/
```

### Linting
```bash
flake8 app/
```

## Next Steps

1. ✅ Complete API with mock data
2. 🔄 Integrate PostgreSQL database
3. 🔄 Add Claude AI integration for diet plan generation
4. 🔄 Add AWS S3 for file storage
5. 🔄 Add Redis caching
6. 🔄 Add Stripe payment integration
7. 🔄 Deploy to AWS ECS

## License

Copyright © 2026 Labcorp
