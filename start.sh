#!/bin/bash
cd "$(dirname "$0")"

echo "Starting auth-service (port 8001) and notes-service (port 8002)..."
echo "Logs are combined below. Press Ctrl+C to stop both."
echo ""

# run each service's script in the background, tagging their output
( bash auth-service/run.sh 2>&1 | sed 's/^/[auth]  /' ) &
AUTH_PID=$!

( bash notes-service/run.sh 2>&1 | sed 's/^/[notes] /' ) &
NOTES_PID=$!

# when this script gets Ctrl+C, kill both background processes too
trap "echo ''; echo 'Stopping both services...'; kill $AUTH_PID $NOTES_PID 2>/dev/null; exit" INT

wait