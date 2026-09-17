#!/bin/bash
cd "$(dirname "$0")"
[ ! -d venv ] && python -m venv venv
source venv/Scripts/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8002