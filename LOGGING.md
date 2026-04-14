# Logging Documentation

## Overview

Both backend (FastAPI) and frontend (React) use structured logging with ISO 8601 timestamps, environment-based log levels, and stack traces for exceptions.

## Unified Configuration (Single Source of Truth)

Set **one** variable in `.env` for both backend and frontend:

```bash
ENVIRONMENT=production  # local, staging, production
LOG_LEVEL=WARNING       # DEBUG, INFO, WARNING, ERROR, CRITICAL
```

**How it works:** Docker automatically maps `LOG_LEVEL` → `VITE_LOG_LEVEL` for the frontend. You don't need to set separate `VITE_*` variables.

### Environment-Based Defaults

| Environment  | Default Level | Description |
| ------------ | ------------- | ----------- |
| `local`      | DEBUG         | Verbose     |
| `staging`    | INFO          | Standard    |
| `production` | WARNING       | Minimal     |

**Priority:** Explicit `LOG_LEVEL` overrides environment-based defaults.

## Log Output

### Backend

**Format:** `[2026-04-14T08:13:15.246Z] [INFO] [module:function:line] Message`

**View logs:** `docker compose logs backend -f`

### Frontend

**Format:** `[2026-04-14T08:13:15.246Z] [INFO] [Component] Message`

**View logs:** Browser DevTools Console (F12)

## Usage Examples

### Backend

```python
from app.core.logger import get_logger, log_exception

logger = get_logger(__name__)
logger.info(f"User {user_id} created item")
logger.warning(f"Invalid access attempt")

try:
    # operation
except Exception as e:
    log_exception(logger, e, context="Failed to create item")
    raise
```

### Frontend

```typescript
import { logger } from "@/lib/logger";

logger.info("User logged in", "useAuth");
logger.warn("Session expired", "useAuth");
logger.error("Failed to fetch", "useAuth", error);
logger.exception(error, "ComponentName");
```

## Configuration Examples

**Minimal logging (production):**

```bash
ENVIRONMENT=production
LOG_LEVEL=WARNING
```

**Verbose logging (debugging):**

```bash
ENVIRONMENT=local
LOG_LEVEL=DEBUG
```

**After changing `.env`, restart:**

```bash
docker compose down
docker compose watch
```

## Troubleshooting

### Backend logs not showing

- Check `LOG_LEVEL` in `.env` (use `WARNING` not `WARN`)
- Verify: `docker compose logs backend | head -20`
- Should see: "Starting FastAPI with log level: warning"
- Rebuild if needed: `docker compose build backend --no-cache`

### Frontend logs not showing

- Check `LOG_LEVEL` in `.env` (no need for `VITE_LOG_LEVEL`)
- Rebuild frontend: `docker compose build frontend`
- Check browser console for: `[Logger] Configured with log level: WARN`
- Verify browser DevTools console filter settings

### Too many/few logs

- Set `LOG_LEVEL=WARNING` for minimal logging
- Set `LOG_LEVEL=DEBUG` for maximum verbosity

## Best Practices

1. **Use appropriate levels:** DEBUG (temporary), INFO (business events), WARN (recoverable issues), ERROR (failures)
2. **Include context:** `logger.info(f"User {user_id} performed action")`
3. **Log exceptions with stack traces:** Use `log_exception()` helper
4. **Don't log sensitive data:** No passwords, tokens, or credit cards
5. **Production:** Use WARNING level to reduce noise and improve performance
