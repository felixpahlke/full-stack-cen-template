#! /usr/bin/env bash

set -e
set -x

# Let the DB start
python app/backend_pre_start.py

# Each FastAPI worker owns migrate/verify/seed in its lifespan. PostgreSQL advisory
# locking serializes workers and replicas, so prestart only waits for reachability.
