#! /usr/bin/env bash

set -e
set -x

# cd backend
# python -c "import app.main; import json; print(json.dumps(app.main.app.openapi()))" > ../openapi.json
# cd ..

yq -o json backend/docs/openapi.yaml > ./openapi.json

node frontend/modify-openapi-operationids.js
mv openapi.json frontend/
cd frontend
npm run generate-client
npx prettier --write ./src/client
