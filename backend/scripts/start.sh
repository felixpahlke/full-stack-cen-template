#!/bin/bash
set -e

# Convert LOG_LEVEL to lowercase for FastAPI CLI
# FastAPI CLI expects: debug, info, warning, error, critical
# Our app uses: DEBUG, INFO, WARNING, ERROR, CRITICAL

if [ -n "$LOG_LEVEL" ]; then
    # Convert to lowercase
    FASTAPI_LOG_LEVEL=$(echo "$LOG_LEVEL" | tr '[:upper:]' '[:lower:]')
else
    # Determine from ENVIRONMENT if LOG_LEVEL not set
    case "${ENVIRONMENT:-local}" in
        local)
            FASTAPI_LOG_LEVEL="debug"
            ;;
        staging)
            FASTAPI_LOG_LEVEL="info"
            ;;
        production)
            FASTAPI_LOG_LEVEL="warning"
            ;;
        *)
            FASTAPI_LOG_LEVEL="info"
            ;;
    esac
fi

echo "Starting FastAPI with log level: $FASTAPI_LOG_LEVEL"

# Start FastAPI with the appropriate log level
exec fastapi run --workers 4 --log-level "$FASTAPI_LOG_LEVEL" app/main.py

