#!/bin/bash

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "Virtual environment not found. Creating one..."
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Run the FastAPI application
echo "Starting NutriAI Backend API..."
echo "API: http://localhost:8000"
echo "Docs: http://localhost:8000/api/docs"
echo ""
python -m app.main
